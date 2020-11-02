FROM swift:latest as builder
WORKDIR /root
COPY . .
RUN swift build -c release
RUN rm .dockerignore

FROM swift:slim
RUN groupadd --gid 1000 fn
RUN adduser --uid 1000 --gid 1000 fn
WORKDIR /function

COPY --from=builder /root/.build/release/fnswift-example .

CMD ["/function/fnswift-example"]
