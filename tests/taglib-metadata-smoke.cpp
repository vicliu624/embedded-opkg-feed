// Persist UTF-8 MP3 tags and verify C/C++ interfaces agree after reopening.
#include <cassert>
#include <cstring>
#include <iostream>
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tag_c.h>

int main(int argc, char **argv)
{
    assert(argc == 2);
    const char *title = "TDVP \xe9\x9f\xb3\xe9\xa2\x91 metadata";
    {
        TagLib::FileRef file(argv[1]);
        assert(!file.isNull() && file.tag() && file.audioProperties());
        assert(file.audioProperties()->sampleRate() == 44100);
        assert(file.audioProperties()->channels() == 2);
        file.tag()->setTitle(TagLib::String(title, TagLib::String::UTF8));
        file.tag()->setArtist("TDVP Device Team");
        file.tag()->setAlbum("Codec acceptance");
        file.tag()->setTrack(42);
        file.tag()->setYear(2026);
        assert(file.save());
    }
    {
        TagLib::FileRef file(argv[1]);
        assert(!file.isNull());
        assert(file.tag()->title().to8Bit(true) == title);
        assert(file.tag()->track() == 42 && file.tag()->year() == 2026);
    }
    TagLib_File *file = taglib_file_new(argv[1]);
    assert(file && taglib_file_is_valid(file));
    TagLib_Tag *tag = taglib_file_tag(file);
    assert(tag);
    assert(std::strcmp(taglib_tag_title(tag), title) == 0);
    taglib_tag_set_comment(tag, "CPU0 metadata check");
    assert(taglib_file_save(file));
    taglib_tag_free_strings();
    taglib_file_free(file);
    {
        TagLib::FileRef reopened(argv[1]);
        assert(!reopened.isNull());
        assert(reopened.tag()->comment() == "CPU0 metadata check");
        assert(reopened.tag()->title().to8Bit(true) == title);
    }
    std::cout << "TagLib: PASS UTF-8 title, MP3 persistence, C/C++ agreement and audio metadata\n";
}
