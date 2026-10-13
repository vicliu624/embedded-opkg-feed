#include <sodium.h>
#include <seccomp.h>
#include <uv.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int callbacks = 0;
static void timer_ready(uv_timer_t *timer) {
    callbacks++;
    uv_close((uv_handle_t *)timer, NULL);
}

int main(void) {
    if (sodium_init() < 0) return 1;
    const unsigned char message[] = "TDVP authenticated model metadata";
    unsigned char seed[crypto_sign_SEEDBYTES] = {0};
    unsigned char public_key[crypto_sign_PUBLICKEYBYTES], secret_key[crypto_sign_SECRETKEYBYTES];
    unsigned char signature[crypto_sign_BYTES];
    if (crypto_sign_seed_keypair(public_key, secret_key, seed) != 0) return 2;
    if (crypto_sign_detached(signature, NULL, message, sizeof(message), secret_key) != 0) return 3;
    if (crypto_sign_verify_detached(signature, message, sizeof(message), public_key) != 0) return 4;
    signature[0] ^= 1;
    if (crypto_sign_verify_detached(signature, message, sizeof(message), public_key) == 0) return 5;
    unsigned char key[crypto_aead_xchacha20poly1305_ietf_KEYBYTES] = {0};
    unsigned char nonce[crypto_aead_xchacha20poly1305_ietf_NPUBBYTES] = {0};
    unsigned char ciphertext[sizeof(message) + crypto_aead_xchacha20poly1305_ietf_ABYTES];
    unsigned char restored[sizeof(message)];
    unsigned long long size = 0, restored_size = 0;
    if (crypto_aead_xchacha20poly1305_ietf_encrypt(ciphertext, &size, message, sizeof(message),
                                                 public_key, sizeof(public_key), NULL, nonce, key) != 0) return 6;
    if (crypto_aead_xchacha20poly1305_ietf_decrypt(restored, &restored_size, NULL, ciphertext, size,
                                                 public_key, sizeof(public_key), nonce, key) != 0) return 7;
    if (restored_size != sizeof(message) || memcmp(restored, message, sizeof(message)) != 0) return 8;
    ciphertext[0] ^= 1;
    if (crypto_aead_xchacha20poly1305_ietf_decrypt(restored, &restored_size, NULL, ciphertext, size,
                                                 public_key, sizeof(public_key), nonce, key) == 0) return 9;
    sodium_memzero(secret_key, sizeof(secret_key));

    if (seccomp_arch_native() != SCMP_ARCH_RISCV64) return 10;
    int syscall = seccomp_syscall_resolve_name("getpid");
    if (syscall < 0) return 11;
    scmp_filter_ctx filter = seccomp_init(SCMP_ACT_ALLOW);
    if (!filter || seccomp_rule_add(filter, SCMP_ACT_ERRNO(EPERM), syscall, 0) != 0) return 12;
    FILE *output = tmpfile();
    if (!output || seccomp_export_bpf(filter, fileno(output)) != 0 || ftell(output) <= 0) return 13;
    fclose(output);
    seccomp_release(filter);
    /* Only construct/export: do not install a syscall filter in the test or desktop. */

    uv_loop_t loop;
    uv_timer_t timer;
    if (uv_loop_init(&loop) != 0 || uv_timer_init(&loop, &timer) != 0) return 14;
    if (uv_timer_start(&timer, timer_ready, 0, 0) != 0) return 15;
    uv_run(&loop, UV_RUN_DEFAULT);
    if (callbacks != 1 || uv_loop_close(&loop) != 0) return 16;
    puts("libsodium signing/AEAD positive-negative cases, RISC-V seccomp filter export, libuv event loop: PASS");
    return 0;
}
