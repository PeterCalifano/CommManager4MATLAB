SRC_DIR=.
DST_DIR=protoGen
PROTODEF=addressbook

protoc -I=$SRC_DIR --cpp_out=$DST_DIR $SRC_DIR/$PROTODEF.proto