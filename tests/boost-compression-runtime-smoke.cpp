/* SPDX-License-Identifier: MIT */
#include <boost/iostreams/filtering_stream.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#include <boost/iostreams/filter/bzip2.hpp>
#include <boost/iostreams/filter/lzma.hpp>
#include <boost/iostreams/filter/zstd.hpp>
#include <sstream>
#include <string>
#include <cstdio>

template<class Compressor, class Decompressor>
bool roundtrip(const std::string &input)
{
 std::stringstream encoded;
 {
  boost::iostreams::filtering_ostream writer;
  writer.push(Compressor()); writer.push(encoded);
  writer.write(input.data(), input.size()); writer.reset();
 }
 if (encoded.str().empty()) return false;
 boost::iostreams::filtering_istream reader;
 reader.push(Decompressor()); reader.push(encoded);
 std::ostringstream output;
 output << reader.rdbuf();
 return output.str() == input;
}

int main()
{
 std::string input;
 for (int i = 0; i < 1024; i++) input += "TDVP-compression-" + std::to_string(i) + "\n";
 if (!roundtrip<boost::iostreams::gzip_compressor, boost::iostreams::gzip_decompressor>(input)) return 1;
 if (!roundtrip<boost::iostreams::bzip2_compressor, boost::iostreams::bzip2_decompressor>(input)) return 2;
 if (!roundtrip<boost::iostreams::lzma_compressor, boost::iostreams::lzma_decompressor>(input)) return 3;
 if (!roundtrip<boost::iostreams::zstd_compressor, boost::iostreams::zstd_decompressor>(input)) return 4;
 std::puts("Boost Iostreams target: PASS gzip, bzip2, LZMA and zstd exact payload roundtrips");
 return 0;
}
