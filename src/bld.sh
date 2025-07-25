mkdir darwin_x86_64/
mkdir win32
docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=x86_64-w64-mingw32  multiarch/crossbuild cc -Wno-implicit-function-declaration what.c -o win32/what.exe
docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=x86_64-apple-darwin multiarch/crossbuild cc -Wno-implicit-function-declaration what.c -o darwin_x86_64/what

file */what*
