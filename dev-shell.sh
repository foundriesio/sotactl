docker run --rm -it -u $(id -u):$(id -g) -v $PWD:$PWD -w $PWD --env-file=$PWD/.env sotactl bash
