if [ -d /usr/local/go ]
then
	export GOPATH=$HOME/go
	export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
fi
