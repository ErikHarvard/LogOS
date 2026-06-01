
#include <unistd.h>
#include <fcntl.h>

int main() {
    char buf[4096];
    int fd1 = open("/proc/self/exe", O_RDONLY);
    int fd2 = open("self_copy.bin", O_WRONLY | O_CREAT | O_TRUNC, 0666);
    ssize_t n;
    while ((n = read(fd1, buf, sizeof(buf))) > 0)
        write(fd2, buf, n);
    close(fd1);
    close(fd2);
    write(1, "Self‑replication complete: self_copy.bin created\n", 48);
    return 0;
}
