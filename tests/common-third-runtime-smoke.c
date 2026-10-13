#include <jansson.h>
#include <zip.h>
#include <lzo/lzo1x.h>
#include <libmnl/libmnl.h>
#include <libnftnl/table.h>
#include <linux/netfilter.h>
#include <libxml/parser.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    json_error_t error;
    json_t *json = json_loads("{\"items\":[1,2,3]}", JSON_REJECT_DUPLICATES, &error);
    if (!json || json_array_size(json_object_get(json, "items")) != 3) return 1;
    char *encoded = json_dumps(json, JSON_COMPACT);
    if (!encoded) return 2;
    free(encoded);
    json_decref(json);
    if (json_loads("{\"x\":1,\"x\":2}", JSON_REJECT_DUPLICATES, &error)) return 3;

    unsigned char message[4096];
    struct nlmsghdr *header = mnl_nlmsg_put_header(message);
    header->nlmsg_type = 16;
    mnl_attr_put_u32(header, 1, 42);
    struct nlattr *attribute = mnl_nlmsg_get_payload(header);
    if (mnl_attr_validate(attribute, MNL_TYPE_U32) || mnl_attr_get_u32(attribute) != 42) return 4;
    struct nftnl_table *table = nftnl_table_alloc();
    if (!table) return 5;
    nftnl_table_set_u32(table, NFTNL_TABLE_FAMILY, NFPROTO_INET);
    if (nftnl_table_set_str(table, NFTNL_TABLE_NAME, "tdvp-fixture")) return 6;
    if (strcmp(nftnl_table_get_str(table, NFTNL_TABLE_NAME), "tdvp-fixture")) return 7;
    nftnl_table_free(table);

    const unsigned char plain[] = "TDVP compression and archive runtime fixture";
    unsigned char compressed[256], restored[256];
    lzo_uint size = sizeof(compressed), restored_size = sizeof(restored);
    void *work = malloc(LZO1X_1_MEM_COMPRESS);
    if (!work || lzo_init() != LZO_E_OK) return 8;
    if (lzo1x_1_compress(plain, sizeof(plain), compressed, &size, work) != LZO_E_OK) return 9;
    if (lzo1x_decompress_safe(compressed, size, restored, &restored_size, NULL) != LZO_E_OK || restored_size != sizeof(plain) || memcmp(plain, restored, sizeof(plain))) return 10;
    free(work);

    char path[] = "tdvp-zip-fixture-XXXXXX";
    int descriptor = mkstemp(path);
    if (descriptor < 0) return 11;
    close(descriptor);
    int zip_error;
    zip_t *archive = zip_open(path, ZIP_CREATE | ZIP_TRUNCATE, &zip_error);
    if (!archive) { unlink(path); return 12; }
    zip_source_t *source = zip_source_buffer(archive, plain, sizeof(plain), 0);
    if (!source || zip_file_add(archive, "sample", source, 0) < 0) return 13;
    if (zip_close(archive)) return 14;
    archive = zip_open(path, ZIP_RDONLY, &zip_error);
    if (!archive) return 15;
    zip_file_t *entry = zip_fopen(archive, "sample", 0);
    if (!entry || zip_fread(entry, restored, sizeof(restored)) != sizeof(plain) || memcmp(plain, restored, sizeof(plain))) return 16;
    zip_fclose(entry);
    zip_close(archive);
    unlink(path);

    const char *xml = "<root><value>42</value></root>";
    const char *stylesheet = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:output method='text'/><xsl:template match='/'><xsl:value-of select='/root/value'/></xsl:template></xsl:stylesheet>";
    xmlDocPtr input = xmlReadMemory(xml, strlen(xml), "input.xml", NULL, XML_PARSE_NONET);
    xmlDocPtr style_doc = xmlReadMemory(stylesheet, strlen(stylesheet), "style.xml", NULL, XML_PARSE_NONET);
    if (!input || !style_doc) return 17;
    xsltStylesheetPtr style = xsltParseStylesheetDoc(style_doc);
    if (!style) return 18;
    xmlDocPtr output = xsltApplyStylesheet(style, input, NULL);
    xmlChar *text = NULL;
    int length = 0;
    if (!output || xsltSaveResultToString(&text, &length, output, style) || length != 2 || memcmp(text, "42", 2)) return 19;
    xmlFree(text);
    xmlFreeDoc(output);
    xsltFreeStylesheet(style);
    xmlFreeDoc(input);
    xsltCleanupGlobals();
    xmlCleanupParser();
    puts("Jansson, mnl/nftnl message objects, LZO, ZIP roundtrip and XSLT transformation: PASS");
    return 0;
}
