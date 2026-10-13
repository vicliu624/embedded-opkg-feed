/* SPDX-License-Identifier: MIT */
#include <archive.h>
#include <archive_entry.h>
#include <gcrypt.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
 unsigned char digest[32];
 const unsigned char expected[32] = {
  0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,
  0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad
 };
 assert(gcry_check_version(GCRYPT_VERSION) != NULL);
 gcry_md_hash_buffer(GCRY_MD_SHA256, digest, "abc", 3);
 assert(memcmp(digest, expected, 32) == 0);
 char storage[16384], output[64] = {0};
 const char contents[] = "tdvp-archive-roundtrip";
 size_t used = 0;
 struct archive *writer = archive_write_new();
 assert(writer != NULL);
 assert(archive_write_set_format_zip(writer) == ARCHIVE_OK);
 assert(archive_write_open_memory(writer, storage, sizeof(storage), &used) == ARCHIVE_OK);
 struct archive_entry *entry = archive_entry_new();
 archive_entry_set_pathname(entry, "fixture.txt");
 archive_entry_set_filetype(entry, AE_IFREG);
 archive_entry_set_perm(entry, 0600);
 archive_entry_set_size(entry, sizeof(contents));
 assert(archive_write_header(writer, entry) == ARCHIVE_OK);
 assert(archive_write_data(writer, contents, sizeof(contents)) == sizeof(contents));
 archive_entry_free(entry);
 assert(archive_write_close(writer) == ARCHIVE_OK);
 assert(archive_write_free(writer) == ARCHIVE_OK);
 struct archive *reader = archive_read_new();
 archive_read_support_format_zip(reader);
 archive_read_support_filter_all(reader);
 assert(archive_read_open_memory(reader, storage, used) == ARCHIVE_OK);
 assert(archive_read_next_header(reader, &entry) == ARCHIVE_OK);
 assert(strcmp(archive_entry_pathname(entry), "fixture.txt") == 0);
 assert(archive_read_data(reader, output, sizeof(output)) == sizeof(contents));
 assert(memcmp(output, contents, sizeof(contents)) == 0);
 assert(archive_read_next_header(reader, &entry) == ARCHIVE_EOF);
 assert(archive_read_free(reader) == ARCHIVE_OK);
 puts("Base SDK consumers: PASS libgcrypt SHA256 known vector and libarchive ZIP exact roundtrip");
 return 0;
}
