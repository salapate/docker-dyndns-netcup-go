# docker-dyndns-netcup-go

A Docker image built for Hentras work, that can be found here: https://github.com/Hentra/dyndns-netcup-go



## Usage
| ENV | Default |
| --- | ---|
| TZ | Europe/Berlin |
| DDNS_INTERVAL | */5 * * * * |
|||
| CUSTOMERNR | 12345 |
| APIKEY | abcdefghijklmnopqrstuvwxyz |
| APIPASSWORD | abcdefghijklmnopqrstuvwxyz |
| DOMAIN | mydomain.com |
| HOST | server |
| USE_IPV6 | false |
| CHANGE_TTL | true |
| APIURL | https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON |

## Todos
1. Thorough testing.
2. Multi-arch support.
3. Healthcheck to be implemented.