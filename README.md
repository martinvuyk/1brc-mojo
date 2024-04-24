# 1 Billion Row Challenge in Mojo

### Machine used as reference
Intel i7 7700HQ , 4 cores 8 threads @ 2.8 GHz

This Mojo version `mojo 24.2.1` takes 16.3s without yet having a hash map and min max calculations implemented. The parallelize function doesn't use every thread available for some reason

Go takes about 6.5s on average, in [this one](https://github.com/gunnarmorling/1brc/tree/main/src/main/go/AlexanderYastrebov) and [this other one](https://github.com/benhoyt/go-1brc)

The Java version from [Artsiom Korzun](https://github.com/gunnarmorling/1brc/blob/main/src/main/java/dev/morling/onebrc/CalculateAverage_artsiomkorzun.java) takes 3.8s
