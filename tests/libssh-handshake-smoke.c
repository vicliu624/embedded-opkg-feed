/* SPDX-License-Identifier: MIT */
#include <libssh/libssh.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
 assert(argc == 3);
 ssh_session session = ssh_new();
 assert(session != NULL);
 int parse_config = 0;
 unsigned int port = (unsigned int)strtoul(argv[2], NULL, 10);
 long timeout = 10;
 assert(port > 0 && port <= 65535);
 assert(ssh_options_set(session, SSH_OPTIONS_PROCESS_CONFIG, &parse_config) == SSH_OK);
 assert(ssh_options_set(session, SSH_OPTIONS_HOST, argv[1]) == SSH_OK);
 assert(ssh_options_set(session, SSH_OPTIONS_PORT, &port) == SSH_OK);
 assert(ssh_options_set(session, SSH_OPTIONS_TIMEOUT, &timeout) == SSH_OK);
 if (ssh_connect(session) != SSH_OK) {
  fprintf(stderr, "SSH handshake failed: %s\n", ssh_get_error(session));
  ssh_free(session);
  return 1;
 }
 ssh_key key = NULL;
 unsigned char *hash = NULL;
 size_t length = 0;
 assert(ssh_get_server_publickey(session, &key) == SSH_OK);
 assert(ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &length) == SSH_OK);
 char *fingerprint = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hash, length);
 assert(fingerprint != NULL);
 printf("SSH handshake: PASS host key %s\n", fingerprint);
 ssh_string_free_char(fingerprint);
 ssh_clean_pubkey_hash(&hash);
 ssh_key_free(key);
 ssh_disconnect(session);
 ssh_free(session);
 /* No credentials are sent. Authentication and SFTP require separate tests. */
 return 0;
}
