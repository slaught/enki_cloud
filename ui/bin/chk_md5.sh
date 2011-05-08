#!/bin/sh

md5deep -l -r -X config_layout.md5 `paste -s .dirs`
# md5deep -r -x config_layout.md5 `paste -s .dirs`
