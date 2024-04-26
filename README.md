# 1 Billion Row Challenge in Mojo

### Machine used as reference
Intel i7 7700HQ , 4 cores 8 threads @ 2.8 GHz

Mojo version `mojo 24.2.1` takes 16.3s without yet having a hash map and min max calculations implemented. The parallelize function doesn't use every thread available for some reason.
Mojo nightly `mojo 2024.4.2414` takes 7.5s but also doesn't use every thread. Performance gain was because file.read_bytes was [refactored to not copy data](https://github.com/modularml/mojo/commit/3f39cfb042e703ab168386555efbf5e7b29dfd8c)

Go takes about 6.5s on average, in [this one](https://github.com/gunnarmorling/1brc/tree/main/src/main/go/AlexanderYastrebov) and [this other one](https://github.com/benhoyt/go-1brc)

The Java version from [Artsiom Korzun](https://github.com/gunnarmorling/1brc/blob/main/src/main/java/dev/morling/onebrc/CalculateAverage_artsiomkorzun.java) takes 3.8s
