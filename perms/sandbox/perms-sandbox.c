// perms-sandbox: run a program with a Wayland security context attached (security-context-v1).
//   perms-sandbox APP_ID CMD [ARGS...]
// Hyprland hides its privileged globals from clients that connect through a security context:
// both clipboard data-control protocols, screencopy, virtual keyboard and pointer, layer-shell,
// global shortcuts and more. The program can still paste into its own focused window.
//
// The context lives until every holder of its close fd has exited. That fd is left open across
// exec, so a program that forks helpers and lets the first process exit keeps its context alive.
// The listening socket lives in $XDG_RUNTIME_DIR/perms/; `perms` removes the ones nobody listens on.
// Exit status: the program's own, or 70 when the context could not be set up (nothing is run then,
// so a blocked app never starts unrestricted by accident).
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <wayland-client.h>
#include "security-context-v1-client-protocol.h"

enum { EXIT_SETUP = 70 };
static const char SANDBOX_ENGINE[] = "perms";

static struct wp_security_context_manager_v1 *manager;

static void on_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (strcmp(interface, wp_security_context_manager_v1_interface.name) == 0)
        manager = wl_registry_bind(registry, name, &wp_security_context_manager_v1_interface, 1);
}
static void on_global_remove(void *data, struct wl_registry *registry, uint32_t name) { (void)data; (void)registry; (void)name; }
static const struct wl_registry_listener registry_listener = { on_global, on_global_remove };

static int fail(const char *what) {
    fprintf(stderr, "perms-sandbox: %s: %s\n", what, errno ? strerror(errno) : "failed");
    return EXIT_SETUP;
}

// $XDG_RUNTIME_DIR/perms/<app_id>-<pid>.sock, bound and listening
static int listen_socket(const char *app_id, char *path, size_t size) {
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    if (!runtime) { errno = 0; return -1; }
    char dir[sizeof(((struct sockaddr_un *)0)->sun_path)];
    snprintf(dir, sizeof dir, "%s/perms", runtime);
    if (mkdir(dir, 0700) != 0 && errno != EEXIST) return -1;
    int n = snprintf(path, size, "%s/%s-%d.sock", dir, app_id, (int)getpid());
    struct sockaddr_un addr = { .sun_family = AF_UNIX };
    if (n < 0 || (size_t)n >= sizeof addr.sun_path) { errno = ENAMETOOLONG; return -1; }
    memcpy(addr.sun_path, path, (size_t)n + 1);

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    unlink(path);
    if (bind(fd, (struct sockaddr *)&addr, sizeof addr) != 0 || listen(fd, SOMAXCONN) != 0) { close(fd); return -1; }
    return fd;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: perms-sandbox APP_ID CMD [ARGS...]\n");
        return EXIT_SETUP;
    }
    const char *app_id = argv[1];
    if (strchr(app_id, '/')) { errno = EINVAL; return fail("app id must not contain '/'"); }

    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return fail("cannot connect to the Wayland display");
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0) return fail("registry roundtrip");
    if (!manager) { errno = 0; return fail("compositor has no wp_security_context_manager_v1"); }

    char path[256];
    int listen_fd = listen_socket(app_id, path, sizeof path);
    if (listen_fd < 0) return fail("cannot create the context socket");
    int close_pipe[2];
    if (pipe2(close_pipe, O_CLOEXEC) != 0) return fail("pipe");

    char instance[32];
    snprintf(instance, sizeof instance, "%d", (int)getpid());
    struct wp_security_context_v1 *context = wp_security_context_manager_v1_create_listener(manager, listen_fd, close_pipe[1]);
    wp_security_context_v1_set_sandbox_engine(context, SANDBOX_ENGINE);
    wp_security_context_v1_set_app_id(context, app_id);
    wp_security_context_v1_set_instance_id(context, instance);
    wp_security_context_v1_commit(context);
    if (wl_display_roundtrip(display) < 0) return fail("context commit");
    wp_security_context_v1_destroy(context);
    wl_display_disconnect(display);   // the context is owned by the close fd now, not by this connection
    close(listen_fd);
    close(close_pipe[1]);

    // keep the read end across exec: the context stays alive while the program (or a child) holds it
    if (fcntl(close_pipe[0], F_SETFD, 0) != 0) return fail("fcntl");
    unsetenv("WAYLAND_SOCKET");
    if (setenv("WAYLAND_DISPLAY", path, 1) != 0 || setenv("PERMS_SANDBOX", app_id, 1) != 0) return fail("setenv");
    execvp(argv[2], argv + 2);
    return fail(argv[2]);
}
