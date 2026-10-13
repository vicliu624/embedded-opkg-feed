/* SPDX-License-Identifier: MIT */
#define WITH_SERVER 1
#include <libssh/libssh.h>
#include <libssh/libssh_version.h>
#include <libssh/server.h>
#include <libssh/sftp.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
 ssh_key private_key = NULL, public_key = NULL, imported = NULL;
 unsigned char *hash = NULL;
 size_t hash_length = 0;
 char *encoded = NULL;
 assert(ssh_init() == SSH_OK);
 assert(ssh_version(LIBSSH_VERSION_INT) != NULL);
 assert(ssh_pki_generate(SSH_KEYTYPE_ED25519, 0, &private_key) == SSH_OK);
 assert(ssh_pki_export_privkey_to_pubkey(private_key, &public_key) == SSH_OK);
 assert(ssh_pki_export_pubkey_base64(public_key, &encoded) == SSH_OK);
 assert(ssh_pki_import_pubkey_base64(encoded, SSH_KEYTYPE_ED25519, &imported) == SSH_OK);
 assert(ssh_key_cmp(public_key, imported, SSH_KEY_CMP_PUBLIC) == 0);
 assert(ssh_get_publickey_hash(imported, SSH_PUBLICKEY_HASH_SHA256, &hash, &hash_length) == SSH_OK);
 assert(hash_length == 32);
 ssh_clean_pubkey_hash(&hash);
 ssh_string_free_char(encoded);
 ssh_key_free(imported); ssh_key_free(public_key); ssh_key_free(private_key);
 ssh_session session = ssh_new();
 assert(session != NULL);
 const char *host = "127.0.0.1";
 unsigned int port = 2222;
 assert(ssh_options_set(session, SSH_OPTIONS_HOST, host) == SSH_OK);
 assert(ssh_options_set(session, SSH_OPTIONS_PORT, &port) == SSH_OK);
 ssh_bind binding = ssh_bind_new();
 assert(binding != NULL);
 ssh_bind_free(binding);
 /* Resolve the SFTP API without making an unauthenticated network connection. */
 assert(sftp_new != NULL && sftp_server_new != NULL);
 ssh_free(session);
 ssh_finalize();
 puts("libssh: PASS Ed25519 generation, public key roundtrip, SHA256 fingerprint, session and server APIs");
 return 0;
}
