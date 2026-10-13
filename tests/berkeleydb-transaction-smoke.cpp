/* SPDX-License-Identifier: MIT */
#include <db_cxx.h>
#include <cassert>
#include <cstring>
#include <iostream>

int main(int argc, char **argv)
{
 assert(argc == 2);
 DbEnv environment(u_int32_t{0});
 environment.open(argv[1], DB_CREATE | DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_LOG | DB_INIT_TXN, 0700);
 Db database(&environment, 0);
 database.open(nullptr, "transaction.db", nullptr, DB_BTREE, DB_CREATE | DB_AUTO_COMMIT, 0600);
 char key_text[] = "tdvp-key";
 char first_text[] = "committed-value";
 char second_text[] = "aborted-value";
 Dbt key(key_text, sizeof(key_text)), first(first_text, sizeof(first_text));
 Dbt second(second_text, sizeof(second_text));
 DbTxn *transaction = nullptr;
 environment.txn_begin(nullptr, &transaction, 0);
 assert(database.put(transaction, &key, &first, 0) == 0);
 transaction->commit(0);
 environment.txn_begin(nullptr, &transaction, 0);
 assert(database.put(transaction, &key, &second, 0) == 0);
 transaction->abort();
 char buffer[64] = {};
 Dbt value;
 value.set_data(buffer);
 value.set_ulen(sizeof(buffer));
 value.set_flags(DB_DBT_USERMEM);
 assert(database.get(nullptr, &key, &value, 0) == 0);
 assert(value.get_size() == sizeof(first_text) && std::memcmp(buffer, first_text, sizeof(first_text)) == 0);
 database.close(0);
 environment.close(0);
 DbEnv reopened_environment(u_int32_t{0});
 reopened_environment.open(argv[1], DB_INIT_MPOOL | DB_INIT_LOCK | DB_INIT_LOG | DB_INIT_TXN, 0700);
 Db reopened(&reopened_environment, 0);
 reopened.open(nullptr, "transaction.db", nullptr, DB_BTREE, DB_AUTO_COMMIT, 0600);
 std::memset(buffer, 0, sizeof(buffer));
 assert(reopened.get(nullptr, &key, &value, 0) == 0);
 assert(value.get_size() == sizeof(first_text) && std::memcmp(buffer, first_text, sizeof(first_text)) == 0);
 reopened.close(0);
 reopened_environment.close(0);
 std::cout << "Berkeley DB: PASS C++ B-tree put/get, transaction commit/abort and persisted reopen\n";
}
