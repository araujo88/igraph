#!/bin/bash -eu

export DEPS_PATH=/src/deps
mkdir $DEPS_PATH

mkdir build && cd build
# CMAKE_BUILD_TYPE=None is an arbitrary value that prevents the automatic Release
# build type setting, allowing OSS-Fuzz to pass on its own optimization flags.
cmake .. -DIGRAPH_WARNINGS_AS_ERRORS=OFF -DCMAKE_BUILD_TYPE=None
make -j$(nproc)

# Build ICU for linking statically.
cd $SRC/icu/source
./configure --disable-shared --enable-static --disable-layoutex \
   --disable-tests --disable-samples --with-data-packaging=static --prefix=$DEPS_PATH
make install -j$(nproc)

# Ugly hack to get static linking to work for ICU.
# See https://github.com/google/oss-fuzz/issues/7284
cd $DEPS_PATH/lib
ls *.a | xargs -n1 ar x
rm *.a
ar r libicu.a *.{ao,o}
ln -s libicu.a libicudata.a
ln -s libicu.a libicuuc.a
ln -s libicu.a libicui18n.a

# Create seed corpus
zip $OUT/read_gml_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/*.gml \
        $SRC/igraph/tests/regression/*.gml \
        $SRC/igraph/fuzzing/test_inputs/*.gml

zip $OUT/read_pajek_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/links.net \
        $SRC/igraph/tests/unit/bipartite.net \
        $SRC/igraph/tests/unit/pajek*.net \
        $SRC/igraph/tests/regression/*.net \
        $SRC/igraph/fuzzing/test_inputs/*.net

zip $OUT/read_dl_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/*.dl \
        $SRC/igraph/tests/unit/*.dl \
        $SRC/igraph/fuzzing/test_inputs/*.dl

zip $OUT/read_lgl_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/*.lgl \
        $SRC/igraph/tests/unit/*.lgl \
        $SRC/igraph/fuzzing/test_inputs/*.lgl

zip $OUT/read_ncol_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/*.ncol \
        $SRC/igraph/tests/unit/*.ncol \
        $SRC/igraph/fuzzing/test_inputs/*.ncol

zip $OUT/read_graphml_fuzzer_seed_corpus.zip \
        $SRC/igraph/examples/simple/*.graphml \
        $SRC/igraph/tests/unit/*.graphml \
        $SRC/igraph/tests/regression/*.graphml \
        $SRC/igraph/fuzzing/test_inputs/*.graphml

cd $SRC/igraph

XML2_FLAGS="-L$DEPS_PATH/lib -Wl,-Bstatic -lxml2 -lz -llzma -licuuc -licui18n -licudata -Wl,-Bdynamic"

# disabled:  vertex_connectivity_fuzzer
for TARGET in read_gml_fuzzer read_pajek_fuzzer read_dl_fuzzer read_lgl_fuzzer read_ncol_fuzzer read_graphml_fuzzer bliss_fuzzer edge_connectivity_fuzzer vertex_separators_fuzzer
do
  $CXX $CXXFLAGS -I$SRC/igraph/build/include -I$SRC/igraph/include -o $TARGET.o -c ./fuzzing/$TARGET.cpp
  $CXX $CXXFLAGS $LIB_FUZZING_ENGINE $TARGET.o -o $OUT/$TARGET ./build/src/libigraph.a $XML2_FLAGS
done
