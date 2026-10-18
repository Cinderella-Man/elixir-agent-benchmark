FROM hexpm/elixir@sha256:73e79b5a183c6ba8c060a664a430b30f571a890907f899a66ed13b0bd4aa03c2 AS build
ENV ERL_FLAGS="+S 2:2" MIX_ENV=prod
RUN apt-get update && apt-get install -y --no-install-recommends libsctp1 && rm -rf /var/lib/apt/lists/*
WORKDIR /src/tools/memory_collector
COPY tools/memory_collector/mix.exs ./
COPY tools/memory_collector/rel ./rel
COPY lib/eab/memory_collector /src/lib/eab/memory_collector
RUN mix release --path /out/memory-collector && mkdir /out/memory-collector/native && cp /usr/lib/x86_64-linux-gnu/libsctp.so.1* /out/memory-collector/native/
FROM scratch
COPY --from=build /out/ /
