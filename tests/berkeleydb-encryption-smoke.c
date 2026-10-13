/* SPDX-License-Identifier: MIT */
#include <db.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
 assert(argc == 2);
 DB *database = NULL;
 char key_text[] = "fixture-key", payload[] = "encrypted-persistent-payload";
 char buffer[64] = {0};
 DBT key = {0}, data = {0}, output = {0};
 key.data = key_text; key.size = sizeof(key_text);
 data.data = payload; data.size = sizeof(payload);
 output.data = buffer; output.ulen = sizeof(buffer); output.flags = DB_DBT_USERMEM;
 assert(db_create(&database, NULL, 0) == 0);
 assert(database->set_encrypt(database, "public-fixture-passphrase", DB_ENCRYPT_AES) == 0);
 assert(database->open(database, NULL, argv[1], NULL, DB_BTREE, DB_CREATE, 0600) == 0);
 assert(database->put(database, NULL, &key, &data, 0) == 0);
 assert(database->sync(database, 0) == 0);
 assert(database->close(database, 0) == 0);
 database = NULL;
 assert(db_create(&database, NULL, 0) == 0);
 assert(database->set_encrypt(database, "public-fixture-passphrase", DB_ENCRYPT_AES) == 0);
 assert(database->open(database, NULL, argv[1], NULL, DB_BTREE, DB_RDONLY, 0600) == 0);
 assert(database->get(database, NULL, &key, &output, 0) == 0);
 assert(output.size == sizeof(payload) && memcmp(buffer, payload, sizeof(payload)) == 0);
 assert(database->close(database, 0) == 0);
 database = NULL;
 assert(db_create(&database, NULL, 0) == 0);
 assert(database->set_encrypt(database, "wrong-public-fixture-passphrase", DB_ENCRYPT_AES) == 0);
 int result = database->open(database, NULL, argv[1], NULL, DB_BTREE, DB_RDONLY, 0600);
 assert(result != 0);
 database->close(database, 0);
 puts("Berkeley DB C API: PASS AES encrypted put/get, persistent reopen and wrong-passphrase rejection");
 return 0;
}
