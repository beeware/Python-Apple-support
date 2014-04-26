#!/bin/bash

. $(dirname $0)/environment.sh

try $(dirname $0)/prepare-libffi.sh
try $(dirname $0)/prepare-python.sh

echo '== Projects prepared'
