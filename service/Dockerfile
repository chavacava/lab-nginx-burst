FROM golang:1.15.1-alpine AS builder
WORKDIR /go/src/app
COPY ./svc.go .
RUN CGO_ENABLED=0 go build -o ./svc

FROM scratch
WORKDIR /opt
COPY --from=builder /go/src/app/svc .
EXPOSE 8080
ENTRYPOINT [ "/opt/svc" ]


