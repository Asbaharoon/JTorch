TORCH_MODULES=(TH THNN THS)

mkdir -p include
mkdir -p include-swig

# Copy include files

for m in $TORCH_MODULES; do 
    cp -R /usr/local/include/$m ./include/$m; 
    cp -R /usr/local/include/$m ./include-swig/$m;
done

# preprocess all header files, reduce generated code size.
#   0. change '#include <THxxx.h>' to '#include "THxxx.h"'
#   1. remove system headers
#   2. remove CUDA headers
#   3. remove '__thalign__([0-9])'

cd include
for f in $(find . -name \*.h); do        
    cat $f | sed -E "s|<TH(.*)>|\"TH\1\"|g" | grep -v "#include <.*>" | grep -v "#include \"cu.*\.h\"" | sed -e "s/__thalign__([0-9])//g" > ../include-swig/$f
done
cd ..

cd include-swig
cc -P -E -I TH -I THNN -I THS torch-cpu.h > torch-cpu-preprocessed.h
cd ..


# Generates Swig bindings
mkdir -p src/main/java/jtorch/cpu

# remove ((noreturn)), __signed

swig -java -package jtorch.cpu -outdir src/main/java/jtorch/cpu torch-cpu.i

# Compile SWIG generated JNI wrapper code

cc -c torch-cpu_wrap.c \
    -I $JAVA_HOME/include \
    -I $JAVA_HOME/include/darwin \
    -I /usr/local/include/TH \
    -I /usr/local/include/THNN \
    -I /usr/local/include/THS

# Builds dynamic linking library
cc -dynamiclib -undefined suppress -flat_namespace torch-cpu_wrap.o -o libjnitorchcpu.dylib

# Builds jar
mvn clean compile assembly:single
