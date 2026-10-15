#
# Make the Xinu configuration program
#

COMPILER_ROOT	=	/usr/bin/

CC	= ${COMPILER_ROOT}gcc
LEX	= ${COMPILER_ROOT}flex
YACC	= ${COMPILER_ROOT}bison -y	# Flag enables yacc-compatible filenames
CFLAGS	=	-std=gnu89
LFLAGS	=


#
# Name of the configuration program
#

CONFIG	= config

all:		conf.h conf.c

${CONFIG}:	lex.yy.c y.tab.c
		$(CC) ${CFLAGS} -o $@ y.tab.c ${LFLAGS}

lex.yy.c:	config.l
		$(LEX) config.l
		@sed -e 's/yy_size_t yyleng/int yyleng/g' lex.yy.c > lex.yy.tmp && mv lex.yy.tmp lex.yy.c

y.tab.c:	config.y
		@echo "extern	int	yyleng;" > .yyleng
		$(YACC) config.y
	
clean:
		rm -f config lex.yy.c y.tab.c

conf.h:		config Configuration
		./config Configuration conf.c conf.h

conf.c:		config Configuration
		./config Configuration conf.c conf.h

install:	conf.h conf.c
		cp -p conf.h ../include
		cp -p conf.c ../system
