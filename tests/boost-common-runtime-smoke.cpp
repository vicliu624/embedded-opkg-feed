/* SPDX-License-Identifier: MIT */
#include <boost/filesystem.hpp>
#include <boost/thread.hpp>
#include <boost/regex.hpp>
#include <boost/regex/icu.hpp>
#include <boost/archive/text_iarchive.hpp>
#include <boost/archive/text_oarchive.hpp>
#include <boost/serialization/vector.hpp>
#include <boost/locale.hpp>
#include <fstream>
#include <sstream>
#include <vector>
#include <cstdio>

int main(int argc, char **argv)
{
 if (argc != 2) return 64;
 boost::filesystem::path root(argv[1]);
 if (boost::filesystem::exists(root)) return 1;
 boost::filesystem::create_directories(root / "nested");
 std::ofstream(root.string() + "/nested/data") << "tdvp";
 if (boost::filesystem::file_size(root / "nested/data") != 4) return 2;
 int value = 0;
 boost::thread worker([&value] { value = 42; });
 worker.join();
 if (value != 42) return 3;
 boost::smatch match;
 std::string text = "tdvp230";
 if (!boost::regex_match(text, match, boost::regex("(tdvp)([0-9]+)")) || match[2] != "230") return 4;
 boost::u32regex unicode = boost::make_u32regex("\\x{e9}", boost::regex_constants::icase);
 if (!boost::u32regex_match("\xc3\x89", unicode)) return 5;
 std::vector<int> input{1,4,9,16}, output;
 std::stringstream stream;
 { boost::archive::text_oarchive archive(stream); archive << input; }
 { boost::archive::text_iarchive archive(stream); archive >> output; }
 if (input != output) return 6;
 boost::locale::generator generator;
 std::locale locale = generator("en_US.UTF-8");
 if (boost::locale::to_upper("tdvp", locale) != "TDVP") return 7;
 if (boost::locale::normalize("e\xcc\x81", boost::locale::norm_nfc, locale) != "\xc3\xa9") return 8;
 std::puts("Boost target: PASS filesystem, thread, regex/ICU, serialization and Unicode locale normalization");
 return 0;
}
