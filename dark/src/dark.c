/*
 *      DARK -- Data Annotation using Rules and Knowledge
 *
 * Copyright (c) 2014-2015  CNRS
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#include <math.h>
#include <ctype.h>
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define DARK_VERSION "2.3.4"
#define DARK_POSIX

#define unused(v) ((void)(v))
#define swap(t, a, b) do { \
	t __t = (a);       \
	(a)   = (b);       \
	(b)   = __t;       \
} while (0)

/*******************************************************************************
 * Annotated token sequence
 *
 *   Sequence object represent a sequence of tokens anotated with a set of tags
 *   that can span arbitrary number of contiguous tokens. This module provide
 *   all the basis tools to manage the tokens and the tags.
 ******************************************************************************/
typedef struct seq_s seq_t;
typedef struct tok_s tok_t;
typedef struct tag_s tag_t;
struct seq_s {
	int ntok;                   // Number of tokens in the array
	struct tok_s {
		char *raw;          // Raw token string
		int   ntag;         // Number of tag in the array
		struct tag_s {
			char *str;  // Name of the tag
			int   len;  // Number of tokens spaned
		} *tag;             // Array of tag objects
	} tok[];                    // Array of token objects
};

/* seqL_new:
 *   Create a new sequence object on the Lua side from a string or a table of
 *   tokens. If the argument is a string, it is split in space separated tokens
 *   while a table argument give the user full control over what constitue a
 *   token.
 */
static
int seqL_new(lua_State *L) {
	seq_t *seq = NULL;
	// If the argument is a string, it is splitted in white space separated
	// tokens, its the user responsibility that this lead to an approriate
	// tokenization.
	if (lua_isstring(L, 1)) {
		const char *str = lua_tostring(L, 1);
		while (isspace(*str)) str++;
		int ntok = 0;
		for (const char *p = str; *p; ntok++) {
			while (*p && !isspace(*p)) p++;
			while (*p &&  isspace(*p)) p++;
		}
		seq = lua_newuserdata(L, sizeof(seq_t) + ntok * sizeof(tok_t));
		for (int n = 0; n < ntok; n++) {
			seq->tok[n].raw  = NULL;
			seq->tok[n].tag  = NULL;
			seq->tok[n].ntag = 0;
		}
		seq->ntok = ntok;
		luaL_getmetatable(L, "seq_t");
		lua_setmetatable(L, -2);
		for (int n = 0; n < ntok; n++) {
			tok_t *tok = &seq->tok[n];
			const char *raw = str; int len = 0;
			while (*str && !isspace(*str)) str++, len++;
			while (*str &&  isspace(*str)) str++;
			tok->raw = malloc(len + 1);
			if (tok->raw == NULL)
				return luaL_error(L, "out of memory");
			memcpy(tok->raw, raw, len);
			tok->raw[len] = '\0';
		}
	// Else, if the argument is a table, it should contains an array of
	// strings, each one is handled as a separate token. This is the only
	// way to get tokens embedding white spaces.
	} else if (lua_istable(L, 1)) {
		const int ntok = lua_rawlen(L, 1);
		seq = lua_newuserdata(L, sizeof(seq_t) + ntok * sizeof(tok_t));
		for (int n = 0; n < ntok; n++) {
			seq->tok[n].raw  = NULL;
			seq->tok[n].tag  = NULL;
			seq->tok[n].ntag = 0;
		}
		seq->ntok = ntok;
		luaL_getmetatable(L, "seq_t");
		lua_setmetatable(L, -2);
		for (int n = 0; n < ntok; n++) {
			tok_t *tok = &seq->tok[n];
			lua_rawgeti(L, 1, n + 1);
			const char *raw = lua_tostring(L, -1);
			luaL_argcheck(L, 1, raw != NULL, "invalid token");
			const int len = strlen(raw) + 1;
			tok->raw = malloc(len);
			if (tok->raw == NULL)
				return luaL_error(L, "out of memory");
			memcpy(tok->raw, raw, len);
			lua_pop(L, 1);
		}
	// Else, there is a problem, either the user forgot the argument or
	// given one of the wrong type.
	} else if (lua_gettop(L) != 0) {
		return luaL_error(L, "bad argument, string or table expected");
	} else {
		return luaL_error(L, "missing argument");
	}
	return 1;
}

/* seqL_free:
 *   Release all memory used by a sequence object on the C side. This doesn't
 *   free the sequence object itself as it is allocated on the Lua side. This
 *   function should be called only by the Lua garbage collector, it should
 *   never be called directly.
 */
static
int seqL_free(lua_State *L) {
	seq_t *seq = luaL_checkudata(L, 1, "seq_t");
	for (int n = 0; n < seq->ntok; n++) {
		tok_t *tok = &seq->tok[n];
		if (tok->raw != NULL)
			free(tok->raw);
		if (tok->tag != NULL) {
			for (int t = 0; t < tok->ntag; t++)
				if (tok->tag[t].str != NULL)
					free(tok->tag[t].str);
			free(tok->tag);
		}
	}
	return 0;
}

/* seq_istagchr:
 *   Return true iff a character is allowed in a tag name.
 */
static inline
int seq_istagchr(char c) {
	return isalnum(c) || c == '-' || c == '_' || c == '=';
}

/* seq_istag:
 *   Return true iff a string is a valid tag name. i.e. start with an sharp and
 *   is followed only by allowed tag characters.
 */
static
int seq_istag(const char *str) {
	if (str[0] != '#' || str[1] == '\0')
		return 0;
	for (int i = 1; str[i] != '\0'; i++)
		if (!seq_istagchr(str[i]))
			return 0;
	return 1;
}

/* seq_checkindex:
 *   Check if the argument is a valid index for the given sequence and return it
 *   as a 0 based value, else return -1. This take care of handling negative
 *   index from the end of the sequence.
 */
static
int seq_checkindex(lua_State *L, int narg, const seq_t *seq) {
	const int n = luaL_checkinteger(L, narg);
	if (n == 0 || abs(n) > seq->ntok)
		return -1;
	if (n < 0)
		return seq->ntok - n;
	return n - 1;
}

/* seq_add:
 *   Add a new tag to the token [tok] with name [str] and spaning [cnt] tokens.
 *   Duplicate tags are not added but doesn't raise an error.
 */
static
void seq_add(lua_State *L, tok_t *tok, const char *str, int cnt) {
	// First if an exact match of this tag already exists, the tag should
	// not be added again.
	for (int t = 0; t < tok->ntag; t++)
		if (tok->tag[t].len == cnt && !strcmp(tok->tag[t].str, str))
			return;
	// We first take care of allocating a copy of the tag and adding some
	// space for it in the tag array of the token. We should be careful here
	// as we should left everything in the same state if an error happen.
	int   len = strlen(str);
	char *tag = malloc(len + 1);
	if (tag == NULL)
		luaL_error(L, "out of memory");
	memcpy(tag, str, len);
	tag[len] = '\0';
	const int ntag = tok->ntag + 1;
	tag_t *lst = realloc(tok->tag, ntag * sizeof(tag_t));
	if (lst == NULL) {
		free(tag);
		luaL_error(L, "out of memory");
	}
	tok->ntag = ntag, tok->tag = lst;
	// If the allocation success, the tag can be created in the new list and
	// success reported. Special care is needed to ensure that the tag list
	// remain ordered first by tag length and next by insertion order.
	int pos = ntag - 1;
	while (pos > 0) {
		if (lst[pos - 1].len <= cnt)
			break;
		lst[pos] = lst[pos - 1];
		pos--;
	}
	lst[pos].str = tag;
	lst[pos].len = cnt;
}

/* seqL_add:
 *   Method to add a tag to a sequence from Lua. Take the tag name as well as a
 *   start and end index as parameters. The end index default to the same value
 *   as the start one.
 */
static
int seqL_add(lua_State *L) {
	seq_t      *seq = luaL_checkudata  (L, 1, "seq_t");
	const char *str = luaL_checkstring (L, 2);
	luaL_argcheck(L, seq_istag(str), 2, "invalid tag name");
	int n1 = seq_checkindex(L, 3, seq), n2 = n1;
	if (!lua_isnoneornil(L, 4))
		n2 = seq_checkindex(L, 4, seq);
	luaL_argcheck(L, n1 != -1, 3, "invalid index");
	luaL_argcheck(L, n2 != -1, 4, "invalid index");
	luaL_argcheck(L, n2 >= n1, 4, "invalid index");
	seq_add(L, &seq->tok[n1], str, n2 - n1 + 1);
	lua_settop(L, 1);
	return 1;
}

/* seq_rem:
 *   Remove a tag named [str] from the token [tok]. If [len] is not 0, the tag
 *   is removed only if its length match.
 */
static
void seq_rem(lua_State *L, tok_t *tok, const char *str, int len) {
	unused(L);
	// First the tag is searched in the token list, some optimization are
	// possible here but not really worthwile.
	int t;
	for (t = 0; t < tok->ntag; t++) {
		if (strcmp(tok->tag[t].str, str) != 0)  continue;
		if (len != 0 && tok->tag[t].len != len) continue;
		break;
	}
	if (t == tok->ntag)
		return;
	// If the tag was found, it should be freed and the gap should be filled
	// as no hole are allowed.
	free(tok->tag[t].str);
	tok->ntag--;
	for ( ; t < tok->ntag; t++)
		tok->tag[t] = tok->tag[t + 1];
	tok->tag = realloc(tok->tag, tok->ntag * sizeof(tag_t));
}

/* seqL_rem:
 *   Method to remove tags from Lua. This can take from zero to three arguments
 *   and will do :
 *     []            -> remove all tags
 *     [tag]         -> remove all instances of a tag
 *     [tag, p1]     -> remove a tag at a specific position
 *     [tag, p1, p2] -> remove a tag with this exact span
 */
static
int seqL_rem(lua_State *L) {
	const int narg = lua_gettop(L) - 1;
	seq_t *seq  = luaL_checkudata(L, 1, "seq_t");
	int    ntok = seq->ntok;
	// Without argument, all tags should be removed basicaly doing a big
	// part of the free method.
	if (narg == 0) {
		for (int n = 0; n < ntok; n++) {
			tok_t *tok = &seq->tok[n];
			if (tok->tag != NULL) {
				for (int t = 0; t < tok->ntag; t++)
					if (tok->tag[t].str != NULL)
						free(tok->tag[t].str);
				free(tok->tag);
				tok->tag  = NULL;
				tok->ntag = 0;
			}
		}
	// With a single argument which should be a tag name, all instance of
	// this tag should be removed.
	} else if (narg == 1) {
		const char *str = luaL_checkstring (L, 2);
		luaL_argcheck(L, seq_istag(str), 2, "invalid tag name");
		for (int n = 0; n < ntok; n++)
			seq_rem(L, &seq->tok[n], str, 0);
	// With a tag name and a single position argument, the tag should be
	// removed only at this specific position.
	} else if (narg == 2) {
		const char *str = luaL_checkstring (L, 2);
		luaL_argcheck(L, seq_istag(str), 2, "invalid tag name");
		const int n = seq_checkindex(L, 3, seq);
		luaL_argcheck(L, n != -1, 3, "invalid index");
		seq_rem(L, &seq->tok[n], str, 0);
	// And with a tag name as well as two position, the tag is removed only
	// if it cover exactly this span.
	} else {
		const char *str = luaL_checkstring (L, 2);
		luaL_argcheck(L, seq_istag(str), 2, "invalid tag name");
		const int n1 = seq_checkindex(L, 3, seq);
		const int n2 = seq_checkindex(L, 4, seq);
		luaL_argcheck(L, n1 != -1, 3, "invalid index");
		luaL_argcheck(L, n2 != -1, 4, "invalid index");
		luaL_argcheck(L, n2 >= n1, 4, "invalid index");
		seq_rem(L, &seq->tok[n1], str, n2 - n1 + 1);
	}
	lua_settop(L, 1);
	return 1;
}

/* seq_reverse:
 *   Allocate anew sequence object and fill it with a copy of the given sequence
 *   but fully reversed.
 */
static
seq_t *seq_reverse(lua_State *L, seq_t *seq) {
	const int ntok = seq->ntok;
	seq_t *new = lua_newuserdata(L, sizeof(seq_t) + ntok * sizeof(tok_t));
	for (int n = 0; n < ntok; n++) {
		new->tok[n].raw  = NULL;
		new->tok[n].tag  = NULL;
		new->tok[n].ntag = 0;
	}
	new->ntok = ntok;
	luaL_getmetatable(L, "seq_t");
	lua_setmetatable(L, -2);
	for (int n = 0; n < ntok; n++) {
		tok_t *tok = &new->tok[n];
		const char *raw = seq->tok[ntok - n - 1].raw;
		const int   len = strlen(raw);
		tok->raw = malloc(len + 1);
		if (tok->raw == NULL)
			luaL_error(L, "out of memory");
		memcpy(tok->raw, raw, len);
		tok->raw[len] = '\0';
	}
	for (int n = 0; n < ntok; n++) {
		tok_t *tok = &seq->tok[n];
		for (int i = 0; i < tok->ntag; i++) {
			const char *tag = tok->tag[i].str;
			const int   len = tok->tag[i].len;
			const int   pos = ntok - (n + len);
			seq_add(L, &new->tok[pos], tag, len);
		}
	}
	return new;
}

/* seqL_reverse:
 *   Lua method to get a reversed copy of a sequence object.
 */
static
int seqL_reverse(lua_State *L) {
	seq_t *seq = luaL_checkudata(L, 1, "seq_t");
	seq_reverse(L, seq);
	return 1;
}

/* seqL_index:
 *   Index meta-method:
 *     - when called with an integer argument it return a table with a "token"
 *       field with the raw string and an array part containing the tags who
 *       start at this position.
 *     - with a tag argument, it return an array of all appearance of this tag
 *       in the sequence.
 *     - else it try to find a method with this name and return it.
 */
static
int seqL_index(lua_State *L) {
	const seq_t *seq = luaL_checkudata(L, 1, "seq_t");
	// First, we handle the case of an integer index. For this we have to
	// build a table with the token and its associated tags. Having a way to
	// get just the token would be more efficient but this is ok for now.
	if (lua_isnumber(L, 2)) {
		const int n = seq_checkindex(L, 2, seq);
		if (n == -1)
			return luaL_error(L, "index out of bound");
		const tok_t *tok = &seq->tok[n];
		lua_newtable(L);
		lua_pushstring(L, tok->raw);
		lua_setfield(L, -2, "token");
		for (int t = 0; t < tok->ntag; t++) {
			lua_newtable(L);
			lua_pushstring(L, tok->tag[t].str);
			lua_setfield(L, -2, "name");
			lua_pushinteger(L, tok->tag[t].len);
			lua_setfield(L, -2, "length");
			lua_rawseti(L, -2, t + 1);
		}
		return 1;
	}
	// If here, the argument is either a string or invalid so a basic check
	// is done to dismiss the invalid ones.
	if (!lua_isstring(L, 2))
		return 0;
	const char *idx = lua_tostring(L, 2);
	// If the string start with an ampersand, a list of tags should be build
	// and returned.
	if (idx[0] == '#') {
		lua_newtable(L);
		for (int n = 0, cnt = 0; n < seq->ntok; n++) {
			const tok_t *tok = &seq->tok[n];
			for (int t = 0; t < tok->ntag; t++) {
				const tag_t *tag = &tok->tag[t];
				if (!strcmp(tag->str, idx)) {
					lua_newtable(L);
					lua_pushinteger(L, n + 1);
					lua_rawseti(L, -2, 1);
					lua_pushinteger(L, n + tag->len);
					lua_rawseti(L, -2, 2);
					lua_rawseti(L, -2, ++cnt);
				}
			}
		}
		return 1;
	}
	luaL_getmetatable(L, "seq_t");
	lua_getfield(L, -1, "__metatable");
	lua_getfield(L, -1, idx);
	return 1;
}

/* seqL_length:
 *   Length meta-method, return the number of tokens in the sequence and can be
 *   used to now the useable range for indexing.
 */
static
int seqL_length(lua_State *L) {
	seq_t *seq = luaL_checkudata(L, 1, "seq_t");
	lua_pushinteger(L, seq->ntok);
	return 1;
}

/* seqL_tostring:
 *   Meta-method for conversion tostring who search the function in the table
 *   stored in __metatable field so it can be easily provided by the Lua side
 *   without exposing the metatable itself.
 */
static
int seqL_tostring(lua_State *L) {
	luaL_checkudata(L, 1, "seq_t");
	luaL_getmetatable(L, "seq_t");
	lua_getfield(L, -1, "__metatable");
	lua_getfield(L, -1, "tostring");
	if (lua_type(L, -1) == LUA_TNIL)
		return 0;
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);
	return 1;
}

/* seq_open:
 *   Setup the sequence module in the given Lua state. This mean creating the
 *   meta-table and registering the module function in the table on top of the
 *   stack.
 */
static
void seq_open(lua_State *L) {
	static const luaL_Reg seq_meta[] = {
		{"__gc",       seqL_free    },
		{"__len",      seqL_length  },
		{"__index",    seqL_index   },
		{"__tostring", seqL_tostring},
		{NULL, NULL}};
	static const luaL_Reg seq_method[] = {
		{"add",        seqL_add     },
		{"remove",     seqL_rem     },
		{"reverse",    seqL_reverse },
		{NULL, NULL}};
	luaL_newmetatable(L, "seq_t");
	luaL_setfuncs(L, seq_meta, 0);
	luaL_newlib(L, seq_method);
	lua_setfield(L, -2, "__metatable");
	lua_pop(L, 1);
	lua_pushcfunction(L, seqL_new);
	lua_setfield(L, -2, "sequence");
}

/*******************************************************************************
 * Maxent model
 *
 *   This is a very small and basic implementation of maximum entropy model to
 *   predict labels for a sequence of tokens. Features are not customizable,
 *   only tokens in window of size three are used through a 2^16:4 hash kernel
 *   for simplicity and efficiency. It perform very well for simple task like
 *   pos-tagging.
 ******************************************************************************/
typedef struct mem_s mem_t;
struct mem_s {
	int nlbl; char  **lbl;
	int nftr; float  *ftr;
};

typedef struct dat_s dat_t;
typedef struct spl_s spl_t;
struct dat_s {
	int nspl;
	struct spl_s {
		int ref, ftr[12];
	} spl[];
};

/* mem_hash:
 *   Simple implementation of Spooky hash function of Bob Jenkins optimized for
 *   short string as this is the only important case here. Return a single 64bit
 *   value but more can be returned if needed.
 */
static
unsigned long mem_hash(const void *buf, const size_t len) {
	union {
		const unsigned char  *p8;
		const unsigned short *p16;
		const unsigned int   *p32;
		const unsigned long  *p64;
	} key = {.p8 = buf};
	const unsigned long foo = 0xDEADBEEFCAFEBABEULL;
	unsigned long tlen = len;
	unsigned long a = foo, b = foo;
	unsigned long c = foo, d = foo;
	while (tlen >= 16) {
		c += key.p64[0]; d += key.p64[1];
		c = (c << 50) | (c >> (64 - 50)); c += d; a ^= c;
		d = (d << 52) | (d >> (64 - 52)); d += a; b ^= d;
		a = (a << 30) | (a >> (64 - 30)); a += b; c ^= a;
		b = (b << 41) | (b >> (64 - 41)); b += c; d ^= b;
		c = (c << 54) | (c >> (64 - 54)); c += d; a ^= c;
		d = (d << 48) | (d >> (64 - 48)); d += a; b ^= d;
		a = (a << 38) | (a >> (64 - 38)); a += b; c ^= a;
		b = (b << 37) | (b >> (64 - 37)); b += c; d ^= b;
		c = (c << 62) | (c >> (64 - 62)); c += d; a ^= c;
		d = (d << 34) | (d >> (64 - 34)); d += a; b ^= d;
		a = (a <<  5) | (a >> (64 -  5)); a += b; c ^= a;
		b = (b << 36) | (b >> (64 - 36)); b += c; d ^= b;
		if (tlen >= 32) {
			a += key.p64[2]; b += key.p64[3];
			tlen -= 16; key.p64 += 2;
		}
		tlen -= 16; key.p64 += 2;
	}
	d += (const unsigned long)tlen << 56;
	switch (tlen) {
		case 15: d += (const unsigned long)key.p8[14] << 48;
		case 14: d += (const unsigned long)key.p8[13] << 40;
		case 13: d += (const unsigned long)key.p8[12] << 32;
		case 12: d += key.p32[2]; c += key.p64[0];           break;
		case 11: d += (const unsigned long)key.p8[10] << 16;
		case 10: d += (const unsigned long)key.p8[ 9] <<  8;
		case  9: d += (const unsigned long)key.p8[ 8];
		case  8: c += key.p64[0];                            break;
		case  7: c += (const unsigned long)key.p8[ 6] << 48;
		case  6: c += (const unsigned long)key.p8[ 5] << 40;
		case  5: c += (const unsigned long)key.p8[ 4] << 32;
		case  4: c += key.p32[0];                            break;
		case  3: c += (const unsigned long)key.p8[ 2] << 16;
		case  2: c += (const unsigned long)key.p8[ 1] <<  8;
		case  1: c += (const unsigned long)key.p8[ 0];       break;
		case  0: c += foo; d += foo;
	}
	d ^= c; c = (c << 15) | (c >> (64 - 15)); d += c;
	a ^= d; d = (d << 52) | (d >> (64 - 52)); a += d;
	b ^= a; a = (a << 26) | (a >> (64 - 26)); b += a;
	c ^= b; b = (b << 51) | (b >> (64 - 51)); c += b;
	d ^= c; c = (c << 28) | (c >> (64 - 28)); d += c;
	a ^= d; d = (d <<  9) | (d >> (64 -  9)); a += d;
	b ^= a; a = (a << 47) | (a >> (64 - 47)); b += a;
	c ^= b; b = (b << 54) | (b >> (64 - 54)); c += b;
	d ^= c; c = (c << 32) | (c >> (64 - 32)); d += c;
	a ^= d; d = (d << 25) | (d >> (64 - 25)); a += d;
	b ^= a; a = (a << 63) | (a >> (64 - 63)); b += a;
	return a;
}

/* mem_genspl:
 *   Generate a set of samples from a sequence object. For each token in the
 *   sequence a sample is build with features and stored in the [spl] array
 *   which must be big enough. The tag lists are scanned for reference label
 *   and if none are found reference is set to -1.
 */
static
int mem_genspl(const mem_t *mem, const seq_t *seq, spl_t spl[]) {
	const int nspl = seq->ntok;
	unsigned hsh[nspl + 2][4];
	hsh[0][0] = hsh[nspl + 1][0] = 0xDEAD;
	hsh[0][1] = hsh[nspl + 1][1] = 0xBEEF;
	hsh[0][2] = hsh[nspl + 1][2] = 0xCAFE;
	hsh[0][3] = hsh[nspl + 1][3] = 0xBABE;
	for (int n = 0; n < nspl; n++) {
		const char *s = seq->tok[n].raw;
		unsigned long tmp = mem_hash(s, strlen(s));
		hsh[n + 1][0] = (tmp >>  0) & 0xFFFF;
		hsh[n + 1][1] = (tmp >> 16) & 0xFFFF;
		hsh[n + 1][2] = (tmp >> 32) & 0xFFFF;
		hsh[n + 1][3] = (tmp >> 48) & 0xFFFF;
	}
	for (int n = 0; n < nspl; n++) {
		spl_t *s = &spl[n]; s->ref = -1;
		memcpy(s->ftr + 0, hsh[n + 1], 4 * sizeof(unsigned));
		memcpy(s->ftr + 4, hsh[n + 0], 4 * sizeof(unsigned));
		memcpy(s->ftr + 8, hsh[n + 2], 4 * sizeof(unsigned));
		for (int f = 0; f < 4; f++) {
			s->ftr[f + 0] = (s->ftr[f + 0]         ) & 0xFFFF;
			s->ftr[f + 4] = (s->ftr[f + 4] * 0x0DC7) & 0xFFFF;
			s->ftr[f + 8] = (s->ftr[f + 8] * 0x1EEF) & 0xFFFF;
		}
		for (int t = 0; s->ref == -1 && t < seq->tok[n].ntag; t++) {
			const char *lbl = seq->tok[n].tag[t].str;
			for (int l = 0; s->ref == -1 && l < mem->nlbl; l++)
				if (strcmp(lbl, mem->lbl[l]) == 0)
					s->ref = l;
		}
	}
	return nspl;
}

/* memL_new:
 *   Setup a new model object suitable to predict labels given in the table
 *   passed as first argument. If a second argument is given, it must be a table
 *   of sequence objects forming a training dataset for this set of labels and
 *   the model is trained using R-Prop algorithm. If no second arguments are
 *   given, the model remain initialized to zero.
 */
static
int memL_new(lua_State *L) {
	lua_settop(L, 2);
	mem_t *mem = lua_newuserdata(L, sizeof(mem_t));
	mem->nlbl =    0; mem->nftr =    0;
	mem->lbl  = NULL; mem->ftr  = NULL;
	luaL_getmetatable(L, "mem_t");
	lua_setmetatable(L, -2);
	// If the first argument is a string, it is interpreted as a model file
	// name which is loaded and returned.
	if (lua_isstring(L, 1)) {
		const char *str = lua_tostring(L, 1);
		FILE *file = fopen(str, "rb");
		if (file == NULL) {
			const char *msg = strerror(errno);
			return luaL_error(L, "cannot open file \"%s\"", msg);
		}
		if (fread(&mem->nlbl, sizeof(int), 1, file) != 1)
			goto error_rd;
		mem->lbl = malloc(mem->nlbl * sizeof(char *));
		if (mem->lbl == NULL)
			goto error_mem;
		for (int l = 0; l < mem->nlbl; l++)
			mem->lbl[l] = NULL;
		for (int l = 0; l < mem->nlbl; l++) {
			mem->lbl[l] = malloc(64);
			if (mem->lbl[l] == NULL)
				goto error_mem;
			if (fread(mem->lbl[l], 64, 1, file) != 1)
				goto error_rd;
		}
		mem->nftr = mem->nlbl * (1 << 16);
		mem->ftr  = malloc(mem->nftr * sizeof(float));
		if (mem->ftr == NULL)
			goto error_mem;
		if (fread(mem->ftr, mem->nftr * sizeof(float), 1, file) != 1)
			goto error_rd;
		fclose(file);
		return 1;
	    error_mem: lua_pushstring(L, "out of memory");          goto error;
	    error_rd:  lua_pushstring(L, "cannot read model file"); goto error;
	    error:
		fclose(file);
		if (mem->lbl != NULL) {
			for (int l = 0; l < mem->nlbl; l++)
				free(mem->lbl[l]);
			free(mem->lbl);
		}
		return lua_error(L);
	}
	// Setup the list of labels from the table given as first argument, a
	// copy of each string must be made on C side with carefull ordering
	// so cleanup goes well in case of error.
	luaL_checktype(L, 1, LUA_TTABLE);
	mem->nlbl = lua_rawlen(L, 1);
	mem->lbl = malloc(mem->nlbl * sizeof(char *));
	for (int l = 0; l < mem->nlbl; l++)
		mem->lbl[l] = NULL;
	for (int l = 0; l < mem->nlbl; l++) {
		lua_rawgeti(L, 1, l + 1);
		const char *lbl = lua_tostring(L, -1);
		luaL_argcheck(L, 1, lbl != NULL, "invalid label");
		const int len = strlen(lbl) + 1;
		luaL_argcheck(L, 1, len < 63, "overlong label");
		mem->lbl[l] = malloc(64);
		if (mem->lbl[l] == NULL)
			return luaL_error(L, "out of memory");
		memset(mem->lbl[l], 0, 64);
		strcpy(mem->lbl[l], lbl);
		lua_pop(L, 1);
	}
	mem->nftr = mem->nlbl * (1 << 16);
	mem->ftr  = malloc(mem->nftr * sizeof(float));
	// Next, the training dataset is loaded in a temporary userdata stored
	// on the stack so the GC take care of cleaning this. The first pass
	// count the number of sample and validate the table.
	luaL_checktype(L, 2, LUA_TTABLE);
	int nseq = lua_rawlen(L, 2), nspl = 0;
	seq_t *seq[nseq];
	for (int i = 0; i < nseq; i++) {
		lua_rawgeti(L, 2, i + 1);
		seq[i] = luaL_testudata(L, -1, "seq_t");
		luaL_argcheck(L, 2, seq[i] != NULL, "invalid sample");
		nspl += seq[i]->ntok;
		lua_pop(L, 1);
	}
	const int sz = sizeof(dat_t) + nspl * sizeof(spl_t);
	dat_t *trn = lua_newuserdata(L, sz); trn->nspl = 0;
	for (int i = 0; i < nseq; i++) {
		spl_t *spl = trn->spl + trn->nspl;
		trn->nspl += mem_genspl(mem, seq[i], spl);
	}
	// And last, the model can be trained using the resilient propagation
	// algorithm for ten iterations. This should be enough to properly train
	// the model with so few features.
	#define sign(v) ((v) < 0.0f ? -1.0f : ((v) > 0.0f ? 1.0f : 0.0f))
	float *wgh = mem->ftr;
	float *grd = lua_newuserdata(L, mem->nftr * sizeof(float));
	float *gpv = lua_newuserdata(L, mem->nftr * sizeof(float));
	float *stp = lua_newuserdata(L, mem->nftr * sizeof(float));
	for (int f = 0; f < mem->nftr; f++)
		gpv[f] = 0.0f, stp[f] = 0.1f, wgh[f] = 0.0f;
	for (int it = 0; it < 10; it++) {
		// First step is to compute the gradient and value of the
		// objective function at the current point.
		float ll = 0.0f;
		for (int f = 0; f < mem->nftr; f++)
			grd[f] = 0.0f;
		for (int s = 0; s < trn->nspl; s++) {
			spl_t *spl = &trn->spl[s];
			if (spl->ref == -1)
				continue;
			float psi[mem->nlbl];
			for (int y = 0; y < mem->nlbl; y++)
				psi[y] = 0.0f;
			for (int f = 0; f < 12; f++) {
				const int base = spl->ftr[f] * mem->nlbl;
				for (int y = 0; y < mem->nlbl; y++)
					psi[y] += wgh[base + y];
			}
			float Z = psi[0];
			for (int y = 1; y < mem->nlbl; y++) {
				const float V = psi[y];
				if (Z > V) Z = Z + logf(1.0f + expf(V - Z));
				else       Z = V + logf(1.0f + expf(Z - V));
			}
			float pb[mem->nlbl];
			for (int y = 0; y < mem->nlbl; y++)
				pb[y] = expf(psi[y] - Z);
			pb[spl->ref] -= 1.0f;
			for (int f = 0; f < 12; f++) {
				const int base = spl->ftr[f] * mem->nlbl;
				for (int y = 0; y < mem->nlbl; y++)
					grd[base + y] += pb[y];
			}
			ll += Z - psi[spl->ref];
		}
		float r2 = 1.2f, l2 = 0.0f;
		for (int f = 0; f < mem->nftr; f++)
			grd[f] += wgh[f] * r2, l2 += wgh[f] * wgh[f];
		ll += l2 * r2 / 2.0f;
		// Next, this gradient is used to update the current point with
		// the R-Prop optimization algorithm.
		for (int f = 0; f < mem->nftr; f++) {
			const float sgn = grd[f] * gpv[f];
			if (sgn > 0.0f) {
				stp[f] *= 1.2f;
				wgh[f] -= sign(grd[f]) * stp[f];
				gpv[f]  = grd[f];
			} else if (sgn < 0.0f) {
				stp[f]  = stp[f] * 0.5f;
				gpv[f]  = 0.0f;
			} else {
				wgh[f] -= sign(grd[f]) * stp[f];
				gpv[f]  = grd[f];
			}
		}
	}
	lua_pop(L, 4);
	#undef sign
	return 1;
}

/* memL_free
 *   Free all memory associated with a maxent model object, this should not be
 *   called directly but only automaticaly by the garbage collector when the
 *   object is no longer reachable.
 */
static
int memL_free(lua_State *L) {
	mem_t *mem = luaL_checkudata(L, 1, "mem_t");
	if (mem->lbl != NULL) {
		for (int l = 0; l < mem->nlbl; l++)
			if (mem->lbl[l] != NULL)
				free(mem->lbl[l]);
		free(mem->lbl);
		mem->lbl = NULL;
	}
	if (mem->ftr != NULL) {
		free(mem->ftr);
		mem->ftr = NULL;
	}
	return 0;
}

/* memL_write:
 *   Method to write the model to the file given as first argument in a format
 *   suitable for fast loading.
 */
static
int memL_write(lua_State *L) {
	mem_t *mem = luaL_checkudata(L, 1, "mem_t");
	const char *str = luaL_checkstring(L, 2);
	FILE *file = fopen(str, "wb");
	if (file == NULL) {
		const char *msg = strerror(errno);
		return luaL_error(L, "cannot open file \"%s\"", msg);
	}
	fwrite(&mem->nlbl, sizeof(int), 1, file);
	for (int l = 0; l < mem->nlbl; l++)
		fwrite(mem->lbl[l], 64, 1, file);
	fwrite(mem->ftr, mem->nftr, sizeof(float), file);
	fclose(file);
	return 0;
}

/* memL_label:
 *   Use a maxent model to make predictions for the given sequence. The labels
 *   are added as single token tags on the sequence.
 */
static
int memL_label(lua_State *L) {
	mem_t *mem = luaL_checkudata(L, 1, "mem_t");
	seq_t *seq = luaL_checkudata(L, 2, "seq_t");
	const float *wgh = mem->ftr;
	spl_t spl[seq->ntok];
	mem_genspl(mem, seq, spl);
	for (int n = 0; n < seq->ntok; n++) {
		float psi[mem->nlbl];
		for (int y = 0; y < mem->nlbl; y++)
			psi[y] = 0.0f;
		for (int f = 0; f < 12; f++) {
			const int base = spl[n].ftr[f] * mem->nlbl;
			for (int y = 0; y < mem->nlbl; y++)
				psi[y] += wgh[base + y];
		}
		int   lbl = 0;
		float bst = psi[0];
		for (int y = 1; y < mem->nlbl; y++)
			if (psi[y] > bst)
				bst = psi[y], lbl = y;
		seq_add(L, &seq->tok[n], mem->lbl[lbl], 1);
	}
	return 1;
}

/* mem_open:
 *   Setup the maxent module in the given Lua state. This mean creating the
 *   meta-table and registering the module function in the table on top of the
 *   stack.
 */
static
void mem_open(lua_State *L) {
	static const luaL_Reg mem_meta[] = {
		{"__gc",   memL_free },
		{"__call", memL_label},
		{NULL, NULL}};
	static const luaL_Reg mem_method[] = {
		{"label",  memL_label},
		{"write",  memL_write},
		{NULL, NULL}};
	luaL_newmetatable(L, "mem_t");
	luaL_setfuncs(L, mem_meta, 0);
	luaL_newlib(L, mem_method);
	lua_pushvalue(L, -1);
	lua_setfield(L, -3, "__index");
	lua_setfield(L, -2, "__metatable");
	lua_pop(L, 1);
	lua_pushcfunction(L, memL_new);
	lua_setfield(L, -2, "maxent");
}

/*******************************************************************************
 * The parser
 *
 *   Implement a hand-written recusive descent parser with limited recursion to
 *   produce an abstract syntax tree representing the pattern. The parser will
 *   produce the following kinds of nodes:
 *       ' ': Epsilon node
 *       '.': Match anything
 *       't': Match simple tokens
 *       'x': Match tokens via regexp
 *       '#': Match specific tag
 *       '@': Match with a Lua function
 *       'a': Assertion like ^ and $
 *       'c': Capture with tagging
 *       'r': Lazy repetitions
 *       'R': Greedy repetitions
 *       '-': Concatenations
 *       '|': Alternatives
 ******************************************************************************/
typedef struct ast_s ast_t;
typedef struct nod_s nod_t;
struct ast_s {
	struct nod_s {
		nod_t  *nxt;
		int     knd, val;
		int     cnt;
		nod_t **sub;
	} *root, *list;
	int    nstr;
	char **str;
};

/* ast_put:
 *   Add a new string to the pool and return its identifier.
 */
static
int ast_put(lua_State *L, ast_t *ast, const char *val, int len) {
	char **tmp = realloc(ast->str, sizeof(char *) * (ast->nstr + 1));
	if (tmp == NULL)
		luaL_error(L, "out of memory");
	ast->str = tmp;
	char *new = malloc(sizeof(char) * (len + 1));
	if (new == NULL)
		luaL_error(L, "out of memory");
	memcpy(new, val, len);
	new[len] = '\0';
	int id = ast->nstr++;
	ast->str[id] = new;
	return id;
}

/* ast_node:
 *   Allocate a new empty AST node of the specified kind and link it in the
 *   given reference for correct cleanup.
 */
static
nod_t *ast_node(lua_State *L, ast_t *ast, int knd) {
	nod_t *res = malloc(sizeof(nod_t));
	if (res == NULL)
		luaL_error(L, "out of memory");
	res->nxt  = ast->list;
	ast->list = res;
	res->knd  = knd;
	res->val  = res->cnt = 0;
	res->sub  = NULL;
	return res;
}

/* ast_append:
 *   Append a new child to the sub-list of the given node taking care of all
 *   memory managment.
 */
static
void ast_append(lua_State *L, nod_t *nod, nod_t *sub) {
	int     cnt = nod->cnt + 1;
	nod_t **tmp = realloc(nod->sub, sizeof(nod_t *) * cnt);
	if (tmp == NULL)
		luaL_error(L, "out of memory");
	tmp[cnt - 1] = sub;
	nod->cnt = cnt;
	nod->sub = tmp;
}

/* ast_reverse:
 *   Reverse an AST in order to match a pattern backward for look-behind. This
 *   is done just by reversing all the concatenations.
 */
static
void ast_reverse(nod_t *nod) {
	if (nod->knd == '-')
		for (int i = 0; i < nod->cnt / 2; i++)
			swap(nod_t *, nod->sub[i], nod->sub[nod->cnt - i - 1]);
	for (int i = 0; i < nod->cnt; i++)
		ast_reverse(nod->sub[i]);
}

/* ast_atom:
 *   Parse an atom who can be a tag, a litteral, a call... The parsed atom is
 *   transformed as a single node AST.
 */
static
nod_t *ast_atom(lua_State *L, ast_t *ast, const char *str, int len, int *pos) {
	nod_t *nod = ast_node(L, ast, 0);
	// A tag is non-null sequence of tag characters preceded by a '#'
	// character which is part of the tag name.
	if (str[*pos] == '#') {
		int cnt = 1; (*pos)++;
		if (!seq_istagchr(str[*pos]))
			luaL_error(L, "tag name expected after '#'");
		while (*pos < len && seq_istagchr(str[*pos]))
			(*pos)++, cnt++;
		nod->val = ast_put(L, ast, str + *pos - cnt, cnt);
		nod->knd = '#';
	// A function call is an @ followed by a non-zero sequence of valid
	// identifier characters. The @ is not part of the function name.
	} else if (str[*pos] == '@') {
		#define isident(c) (isalnum((c)) || (c) == '_')
		int cnt = 0; (*pos)++;
		if (!isident(str[*pos]))
			luaL_error(L, "function name expected after '@'");
		while (*pos < len && isident(str[*pos]))
			(*pos)++, cnt++;
		nod->val = ast_put(L, ast, str + *pos - cnt, cnt);
		nod->knd = '@';
		#undef isident
	// A Lua regexp is a sequence of characters surrounded by // with simple
	// escapes kept in the pattern who may be zero length.
	} else if (str[*pos] == '/') {
		int cnt = 0; (*pos)++;
		while (*pos < len && str[*pos] != '/') {
			if (str[*pos] == '%') {
				if (*pos == len - 1)
					luaL_error(L, "unfinished escape");
				(*pos)++, cnt++;
			}
			(*pos)++, cnt++;
		}
		nod->val = ast_put(L, ast, str + *pos - cnt, cnt);
		nod->knd = 'x';
		(*pos)++;
	// And finally, a token can also be a simple sequence of alphanumeric
	// characters without any special markers.
	} else if (isalnum(str[*pos])) {
		int cnt = 1; (*pos)++;
		while (*pos < len && isalnum(str[*pos]))
			(*pos)++, cnt++;
		nod->val = ast_put(L, ast, str + *pos - cnt, cnt);
		nod->knd = 't';
	// or a token can also be a sequence of any characters surrounded by
	// single or double quotes. In this case, the token may contain escape
	// sequence who are unescaped.
	} else if (str[*pos] == '"' || str[*pos] == '\'') {
		const char end = str[(*pos)++];
		int cnt = 0;
		while (*pos < len && str[*pos] != end) {
			if (str[*pos] == '%') {
				if (*pos == len - 1)
					luaL_error(L, "unfinished escape");
				(*pos)++, cnt++;
			}
			(*pos)++, cnt++;
		}
		nod->val = ast_put(L, ast, str + *pos - cnt, cnt);
		nod->knd = 't';
		(*pos)++;
		char *res = ast->str[nod->val], *ref = res;
		do {
			if (*ref == '%') ref++;
			*res++ = *ref++;
		} while (ref[-1] != '\0');
	// If everything else failed, the only remaining possibility is an error
	// from the user...
	} else {
		luaL_error(L, "unexpected character '%c'", str[*pos]);
	}
	return nod;
}

/* block:
 *   Main parsing function. This handle most of the grammar with a recursive
 *   descent parser written so that recursion is only needed for grouping
 *   construct.
 *   If all goes well, an abstract syntax tree is returned and the [pos]
 *   variable is set to the first unused character in the buffer.
 */
static
nod_t *ast_block(lua_State *L, ast_t *ast, const char *str, int len, int *pos) {
#define look() (*pos >= len ? -1 : str[(*pos)  ])
#define next() (*pos >= len ? -1 : str[(*pos)++])
#define skip() do { while (isspace(look())) next(); } while (0)
#define number(v) do { v = 0; skip();      \
	while (isdigit(look()))            \
		v = v * 10 + next() - '0'; \
} while (0)
	skip();
	int chr = next();
	// Outer loop for alternative. Each iteration compile one of the member
	// of the current chain. This stop when no more alternative are found in
	// the current block.
	nod_t *alt = NULL;
	while (1) {
		// Inner loop for concatenation. Each iteration parse one item
		// of the sequence and stop either if an alternation symbol is
		// found or at end of current block.
		nod_t *seq = NULL;
		while (chr >= 0) {
			nod_t *atm = NULL;
			if (chr == ')' || chr == ']') {
				(*pos)--;
				break;
			}
			if (chr == '|')
				break;
			// First an atom or a group is expected. As the stop
			// case have been handled, the lookahead character is
			// always consumed here.
			switch (chr) {
				case '*': case '+': case '?':
				case '{': case '}':
					luaL_error(L, "unexpected repetition");
				case '(':
					atm = ast_block(L, ast, str, len, pos);
					skip(); chr = next();
					if (chr != ')')
						luaL_error(L, "miss ')'");
					break;
				case '[': {
					nod_t *tmp;
					if (look() != '#')
						luaL_error(L, "miss tag name");
					atm = ast_atom(L, ast, str, len, pos);
					tmp = ast_block(L, ast, str, len, pos);
					skip(); chr = next();
					if (chr != ']')
						luaL_error(L, "miss ']'");
					ast_append(L, atm, tmp);
					atm->knd = 'c';
					break; }
				case '<': case '>': {
					nod_t *tmp;
					atm = ast_node(L, ast, chr);
					if (next() != '(')
						luaL_error(L, "miss '('");
					tmp = ast_block(L, ast, str, len, pos);
					if (atm->knd == '<')
						ast_reverse(tmp);
					ast_append(L, atm, tmp);
					skip(); chr = next();
					if (chr != ')')
						luaL_error(L, "miss ')'");
					break; }
				case '^': case '$':
					atm = ast_node(L, ast, 'a');
					atm->val = chr;
					break;
				case '.':
					atm = ast_node(L, ast, '.');
					break;
				default:
					(*pos)--;
					atm = ast_atom(L, ast, str, len, pos);
					break;
			}
			skip(); chr = next();
			// Next a suffix may be present indicating some kind of
			// repetition of the atom just parsed.
			if (strchr("?*+{", chr) != NULL) {
				int hi, lo;
				     if (chr == '?') lo = 0, hi = 1;
				else if (chr == '*') lo = 0, hi = 0;
				else if (chr == '+') lo = 1, hi = 0;
				else {
					number(lo); skip(); hi = lo;
					if (look() == ',') {
						next(); number(hi); skip();
					}
					if (next() != '}')
						luaL_error(L, "missing '}'");
				}
				skip(); chr = next();
				if (lo > 0xFF || hi > 0xFF)
					luaL_error(L, "too big repetition");
				if (hi != 0 && hi < lo)
					luaL_error(L, "invalid repetition");
				nod_t *rpt = ast_node(L, ast, 'R');
				rpt->val = (hi << 8) + lo;
				if (chr == '?') {
					rpt->knd = 'r';
					skip(); chr = next();
				}
				ast_append(L, rpt, atm);
				atm = rpt;
			}
			// The new sequence item should be added to the current
			// sequence. Some care is needed as we create the
			// sequence node only if needed.
			if (seq == NULL) {
				seq = atm;
			} else {
				if (seq->knd != '-') {
					nod_t *tmp = ast_node(L, ast, '-');
					ast_append(L, tmp, seq);
					seq = tmp;
				}
				ast_append(L, seq, atm);
			}
		}
		// And the parsed sequence is added to the list of alternatives
		// like for the sequence items. If no more sequences are present
		// the parsing can be stop.
		if (seq == NULL)
			seq = ast_node(L, ast, ' ');
		if (alt == NULL) {
			alt = seq;
		} else {
			if (alt->knd != '|') {
				nod_t *tmp = ast_node(L, ast, '|');
				ast_append(L, tmp, alt);
				alt = tmp;
			}
			ast_append(L, alt, seq);
		}
		if (chr != '|')
			break;
		skip(); chr = next();
	}
	return alt;
#undef number
#undef skip
#undef next
#undef look
}

/* ast_cleanup:
 *   Function to release all memory allocated during the parsing of a pattern.
 *   This should never be called directly, it is registered specially in Lua to
 *   be called by the garbage collector when freeing the AST is possible. This
 *   mean it will be called even in case of errors during parsing.
 */
static
int astL_cleanup(lua_State *L) {
	ast_t *ast = *((ast_t**)lua_touserdata(L, 1));
	if (ast == NULL)
		return 0;
	while (ast->list != NULL) {
		nod_t *nd = ast->list;
		ast->list = nd->nxt;
		free(nd);
	}
	ast->list = NULL;
	for (int i = 0; i < ast->nstr; i++)
		free(ast->str[i]);
	free(ast->str);
	ast->str  = NULL;
	ast->nstr = 0;
	return 0;
}

/* ast_parse:
 *   Parser entry point. This parse the given pattern and return it in AST form
 *   with a special object on the Lua stack that should be poped when the AST is
 *   not needed anymore. This will ensure memory is cleaned up correctly.
 */
static
ast_t *ast_parse(lua_State *L, const char *str) {
	// Before the parsing start, we allocate the AST object on the Lua stack
	// and setup a cleanup function so, if an error happen, all thing will
	// be cleaned correctly.
	ast_t **ast = lua_newuserdata(L, sizeof(ast_t *));
	*ast = NULL;
	lua_newtable(L);
	lua_pushcfunction(L, astL_cleanup);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	// Now, we can just jump to the main parsing function and simply handle
	// errors by raising a Lua error and all will goes well.
	int pos = 0, len = strlen(str);
	*ast = malloc(sizeof(ast_t));
	if (*ast == NULL)
		luaL_error(L, "out of memory");
	(*ast)->list = NULL;
	(*ast)->str  = NULL;
	(*ast)->nstr = 0;
	(*ast)->root = ast_block(L, *ast, str, len, &pos);
	return *ast;
}

#ifdef DARK_DEBUG
static
void ast_dumpsub(ast_t *ast, nod_t *nd, int lvl) {
	static int indent[256];
	printf("    ");
	for (int i = 0; i < lvl; i++) {
		switch (indent[i]) {
			case '+':  printf(" ├─"); indent[i] = '|'; break;
			case '|':  printf(" │ ");                  break;
			case '\\': printf(" └─"); indent[i] = ' '; break;
			case ' ':  printf("   ");                  break;
		}
	}
	if (nd->cnt == 0) printf("─");
	else              printf("─┬");
	switch (nd->knd) {
		case ' ': printf("Epsilon");                         break;
		case 't': printf("Token \"%s\"", ast->str[nd->val]); break;
		case 'x': printf("Regexp /%s/", ast->str[nd->val]);  break;
		case '#': printf("Tag %s", ast->str[nd->val]);       break;
		case '@': printf("Call %s", ast->str[nd->val]);      break;
		case 'a': printf("Assert %c", nd->val);              break;
		case '<': printf("Look-behind");                     break;
		case '>': printf("Look-ahead");                      break;
		case 'c': printf("Capture %s", ast->str[nd->val]);   break;
		case '.': printf("Any");                             break;
		case '-': printf("Concat");                          break;
		case '|': printf("Altern");                          break;
		case 'R': case 'r': {
			const int lo = (nd->val     ) & 0xFF;
			const int hi = (nd->val >> 8) & 0xFF;
			     if (hi == 0)  printf("[%d-n]",  lo);
			else if (hi == lo) printf("[%d]",    lo);
			else               printf("[%d-%d]", lo, hi);
			if (nd->knd == 'r') printf("?");
			break; }
	}
	printf("\n");
	for (int i = 0; i < nd->cnt; i++) {
		indent[lvl] = (i + 1 == nd->cnt) ? '\\' : '+';
		ast_dumpsub(ast, nd->sub[i], lvl + 1);
	}
}
static
void ast_dump(ast_t *ast) {
	ast_dumpsub(ast, ast->root, 0);
}
#endif

/*******************************************************************************
 * The compiler
 *
 *   Compiler to transform an AST to a non-deterministic finite state automaton
 *   represented as a sequence of instruction for a simple virtual machine. The
 *   compiler is very simple but can produce very efficient code.
 ******************************************************************************/
typedef struct nfa_s nfa_t;
typedef struct arc_s arc_t;
struct nfa_s {
	unsigned pos;
	unsigned size;
	struct arc_s {
		unsigned opc  :  8;
		unsigned arg1 : 24;
		unsigned arg2     ;
	} *code;
	int    nstr;
	char **str;
};

enum {
	nfa_Imatch, // Record a match
	nfa_Iany,   // Consume a token and jump to arg2
	nfa_Itoken, // If (token == arg1) jump to arg2 else fail
	nfa_Iregex, // If (token ~= arg1) jump to arg2 else fail
	nfa_Itag,   // If (tag   == arg1) jump to arg2 else fail
	nfa_Icall,  // if (arg1(token))   jump to arg2 else fail
	nfa_Itest,  // If (arg1) jump to arg2 else fail
	nfa_Ilook,  // If (arg1) jump to arg2 else fail
	nfa_Ijump,  // Unconditionaly jump to arg2
	nfa_Isplit, // Jump to both arg1 and arg2 (if different)
	nfa_Iopen,  // Start the arg1 capture and jump to arg2
	nfa_Iclose, // Finish the arg1 capture and jump to arg2
	nfa_Idead,  // Dead code
};
static const struct {
	char *name;
	int   kind;
	int   arg1; // 0:none  1:addr
	int   arg2;
} infos[] = {
	[nfa_Imatch] = {"match", 1, 0, 0},
	[nfa_Iany  ] = {"any",   6, 0, 1},
	[nfa_Itoken] = {"token", 6, 2, 1},
	[nfa_Iregex] = {"regex", 6, 2, 1},
	[nfa_Itag  ] = {"tag",   6, 2, 1},
	[nfa_Icall ] = {"call",  6, 2, 1},
	[nfa_Itest ] = {"test",  6, 3, 1},
	[nfa_Ilook ] = {"look",  6, 3, 1},
	[nfa_Ijump ] = {"jump",  2, 0, 1},
	[nfa_Isplit] = {"split", 2, 1, 1},
	[nfa_Iopen ] = {"open",  3, 2, 1},
	[nfa_Iclose] = {"close", 3, 0, 1},
	[nfa_Idead ] = {"dead",  1, 0, 0},
};

/* nfa_add:
 *   Add a new instruction in the NFA code. If a memory error happen this just
 *   not add the instruction and register the error that will be handled when
 *   compilation is finished.
 */
static
void nfa_add(nfa_t *nfa, int opc, int arg1, int arg2) {
	if (nfa->pos >= nfa->size) {
		if (nfa->size == (unsigned)-1)
			return;
		const unsigned size = (nfa->size == 0) ? 8 : nfa->size * 2;
		arc_t *tmp = realloc(nfa->code, sizeof(arc_t) * size);
		if (tmp == NULL) {
			nfa->size = (unsigned)-1;
			return;
		}
		nfa->code = tmp;
		nfa->size = size;
	}
	const int pc = nfa->pos++;
	nfa->code[pc].opc  = opc;
	nfa->code[pc].arg1 = arg1;
	nfa->code[pc].arg2 = arg2;
}

/* nfa_copy:
 *   Copy a block of instruction to the end of the current buffer taking care of
 *   fixing all the jump adresses.
 */
static
void nfa_copy(nfa_t *nfa, int from, int cnt) {
	if (nfa->size == (unsigned)-1)
		return;
	for (int s = from; s < from + cnt; s++) {
		const arc_t *c = nfa->code;
		int arg1 = c[s].arg1, arg2 = c[s].arg2;
		if (infos[c[s].opc].arg1 == 1) arg1 += nfa->pos - s;
		if (infos[c[s].opc].arg2 == 1) arg2 += nfa->pos - s;
		nfa_add(nfa, c[s].opc, arg1, arg2);
	}
}

/* nfa_gencode:
 *   Main code generation function, this handle all the AST nodes and compile
 *   them to NFA instructions. This doesn't produce very efficient code in all
 *   case but instead produce simple code that will be easily optimised by a
 *   final pass over the code.
 *   Return the pc value after the compilation is done.
 */
static
int nfa_gencode(nfa_t *nfa, const nod_t *nod) {
#define split(t1, t2) nfa_add(nfa, nfa_Isplit, (t1), (t2))
#define jump( t1)     nfa_add(nfa, nfa_Ijump,     0, (t1))
#define at(l) (nfa->code[(l)])
#define pc()  (nfa->pos)
    top:
	// First empty nodes and concatenations. For concatenations, only the
	// first childs is handle via recusion, the last one is done via a jump
	// to the top of loop. (like a tail call)
	if (nod->knd == ' ') return pc();
	if (nod->knd == '-') {
		for (int i = 0; i < nod->cnt - 1; i++)
			nfa_gencode(nfa, nod->sub[i]);
		nod = nod->sub[nod->cnt - 1];
		goto top;
	}
	// Next, the simple match nodes who all directly translate to a single
	// instruction
	if (nod->knd == '.') {
		nfa_add(nfa, nfa_Iany,   0,        pc() + 1);
		return pc();
	} else if (nod->knd == 't') {
		nfa_add(nfa, nfa_Itoken, nod->val, pc() + 1);
		return pc();
	} else if (nod->knd == 'x') {
		nfa_add(nfa, nfa_Iregex, nod->val, pc() + 1);
		return pc();
	} else if (nod->knd == '#') {
		nfa_add(nfa, nfa_Itag,   nod->val, pc() + 1);
		return pc();
	} else if (nod->knd == '@') {
		nfa_add(nfa, nfa_Icall,  nod->val, pc() + 1);
		return pc();
	} else if (nod->knd == 'a') {
		nfa_add(nfa, nfa_Itest,  nod->val, pc() + 1);
		return pc();
	}
	// Look ahead and behind are also quite simple, they translate to a
	// single look instruction followed by the sub-pattern who have to jump
	// on the match instruction in case of success.
	if (nod->knd == '>' || nod->knd == '<') {
		const int l = pc();
		nfa_add(nfa, nfa_Ilook, nod->knd, 0);
		nfa_gencode(nfa, nod->sub[0]);
		nfa_add(nfa, nfa_Ijump, 0, 0);
		at(l).arg2 = pc();
	}
	// Capture are also very simple as we just need to surround the sub tree
	// with open and close instructions.
	if (nod->knd == 'c') {
		nfa_add(nfa, nfa_Iopen, nod->val, pc() + 1);
		if (nod->cnt != 0)
			nfa_gencode(nfa, nod->sub[0]);
		nfa_add(nfa, nfa_Iclose, 0, pc() + 1);
		return pc();
	}
	// Alternatives are a bit more complex but remain simple to handle as it
	// just need to make a chain of split to the sub-patterns.
	if (nod->knd == '|') {
		unsigned base = pc(), loc[nod->cnt];
		for (int i = 0; i < nod->cnt; i++)
			split(0, pc() + 1);
		for (int i = 0; i < nod->cnt; i++) {
			at(base + i).arg1 = pc();
			nfa_gencode(nfa, nod->sub[i]);
			loc[i] = pc();
			jump(0);
		}
		for (int i = 0; i < nod->cnt; i++)
			at(loc[i]).arg2 = pc();
		unsigned last = base + nod->cnt - 1;
		at(last).opc  = nfa_Ijump;
		at(last).arg2 = at(last).arg1;
	}
	// Repetitions are quite complex as they are very generic so it take
	// some care to efficiently produce good code. The "child" macro insert
	// the code for the child taking care of compiling it only one time.
	if (nod->knd == 'r' || nod->knd == 'R') {
		nod_t *blk = nod->sub[0];
		#define child() do {                                \
			if (!es) es=pc(), ee=nfa_gencode(nfa, blk); \
			else nfa_copy(nfa, es, ee - es);            \
		} while (0)
		#define patch(l) do { if (nod->knd == 'r')      \
			swap(unsigned, at(l).arg1, at(l).arg2); \
		} while (0)
		unsigned lo = (nod->val     ) & 0xFF;
		unsigned hi = (nod->val >> 8) & 0xFF, ub = (hi == 0);
		unsigned es = 0, ee = 0, l1 = 0, l2 = 0;
		// First, the case of the star repetition is handled separately
		// to simplify the generic code and generate code a bit more
		// efficient.
		if (lo == 0 && ub) {
			l1 = pc(); split(l1 + 1, 0); child();
			l2 = pc(); jump(0);
			at(l1).arg2 = l2 + 1;
			at(l2).arg2 = l1;
			patch(l1);
			return pc();
		}
		// Next, the fixed number of leading repetitions is generated
		// with the required number of copy. Start position of the last
		// copy is tracked in l1 so for unbounded repetition with can
		// jump back to it.
		for ( ; lo != 0; lo--, hi--) {
			l1 = pc();
			child();
		}
		if (ub) {
			l2 = pc(); split(l1, l2 + 1);
			patch(l2);
			return pc();
		}
		// For max-bounded repetitions, it remain to build the trailing
		// chain of copy. A chain of to-fix jumps to the end is build
		// and fixed in a second step.
		for (l2 = 0; hi != 0; hi--, l2 = l1) {
			l1 = pc(); split(l1 + 1, l2);
			child();
		}
		while (l2 != 0) {
			l1 = at(l2).arg2;
			at(l2).arg2 = pc();
			patch(l2);
			l2 = l1;
		}
		return pc();
		#undef patch
		#undef child
	}
	return pc();
#undef pc
#undef at
#undef jump
#undef split
}

/* nfa_compiler:
 *   Compiler entry point. This take care of running the compiler and optimising
 *   the jump chains to produce good optimized code. Return NULL in case of
 *   memory error.
 */
static
nfa_t *nfa_compile(ast_t *ast) {
	// Compilation is quite simple as we just create an empty NFA object and
	// call the main code generation function on it. We just have to add the
	// starting match instruction and the final jump to it here.
	nfa_t *nfa = malloc(sizeof(nfa_t));
	if (nfa == NULL)
		return NULL;
	nfa->pos  = nfa->size = 0;
	nfa->code = NULL;
	nfa->nstr = 0;
	nfa->str  = NULL;
	nfa_add(nfa, nfa_Imatch, 0, 0);
	nfa_add(nfa, nfa_Isplit, 3, 2);
	nfa_add(nfa, nfa_Iany,   0, 1);
	nfa_gencode(nfa, ast->root);
	nfa_add(nfa, nfa_Ijump, 0, 0);
	if (nfa->size == (unsigned)-1) {
		free(nfa->code);
		free(nfa);
		return NULL;
	}
	// Now, a pipehole opimization pass is done. All the work done here may
	// be done in the code generation step but would make it a lot more
	// complex. The codegen is allowed to produce ineficient code as long as
	// it can be easily optimized here.
	arc_t *c = nfa->code;
	for (unsigned pc = 0; pc < nfa->pos; pc++) {
		// Optimization of the jump chains: for each address argument
		// are patched to its final target by following the jumps
		// instructions.
		if (infos[c[pc].opc].arg1 == 1) {
			unsigned trg = c[pc].arg1;
			while (c[trg].opc == nfa_Ijump)
				trg = c[trg].arg2;
			c[pc].arg1 = trg;
		}
		if (infos[c[pc].opc].arg2 == 1) {
			unsigned trg = c[pc].arg2;
			while (c[trg].opc == nfa_Ijump)
				trg = c[trg].arg2;
			c[pc].arg2 = trg;
		}
	}
	// At this point all jumps should be dead code. This convert them to a
	// nop so they will raise an internal error for debugging.
	for (unsigned pc = 0; pc < nfa->pos; pc++)
		if (c[pc].opc == nfa_Ijump)
			c[pc].opc = nfa_Idead;
	// If everything have gone well, it just remain to steal the string
	// table from the AST. We should be careful to remove it from the tree
	// object as we don't want it to free them.
	nfa->nstr = ast->nstr; ast->nstr = 0;
	nfa->str  = ast->str;  ast->str  = NULL;
	return nfa;
}

/* nfa_free:
 *   Free all memory used by an nfa object.
 */
static
void nfa_free(nfa_t *nfa) {
	for (int i = 0; i < nfa->nstr; i++)
		free(nfa->str[i]);
	free(nfa->str);
	free(nfa);

}

#ifdef DARK_DEBUG
static
void nfa_dump(nfa_t *nfa) {
	arc_t *code = nfa->code;
	for (unsigned pc = 0; pc < nfa->pos; pc++) {
		int opc  = code[pc].opc;
		int arg1 = code[pc].arg1;
		int arg2 = code[pc].arg2;
		printf("    [%3d] \033[1;3%dm", pc, infos[opc].kind);
		printf("%-8s", infos[opc].name);
		switch (infos[opc].arg1) {
			case 1: printf("@%-2d  ", arg1);        break;
			case 2: printf("%s  ", nfa->str[arg1]); break;
			case 3: printf("%c  ", arg1);           break;
		}
		if (infos[opc].arg2) printf("@%-2d", arg2);
		printf("\033[0m\n");
	}
}
#endif

/*******************************************************************************
 * Virtual machine
 ******************************************************************************/
typedef struct exe_s exe_t;
typedef struct cap_s cap_t;
struct exe_s {
	nfa_t *nfa;
	seq_t *seq, *rev;
	struct cap_s {
		int cnt, size;
		struct {
			int tag;
			int beg;
			int end;
		} *pos;
	} *cap;
};

/* exe_run:
 *   Run an NFA on the virtual machine starting from [pc] instruction at [sp]
 *   position on the sequence. Return either the end position of the match or -1
 *   if no match are found.
 */
static
int exe_run(lua_State *L, exe_t *exe, int pc, int sp) {
#define rec(pc, sp) exe_run(L, exe, pc, sp)
	seq_t *seq = exe->seq;
	cap_t *cap = exe->cap;
	const int ntok = seq->ntok;
	char **str = exe->nfa->str;
	while (1) {
		const arc_t    *ins = exe->nfa->code + pc;
		const unsigned  a1  = ins->arg1;
		const unsigned  a2  = ins->arg2;
		switch (ins->opc) {
			// First, handle the simple non-consuming instructions
			// that don't alter the source pointer.
			case nfa_Imatch:
				return sp;
			case nfa_Itest:
				     if (a1 == '^' && sp == 0)    pc = a2;
				else if (a1 == '$' && sp == ntok) pc = a2;
				else return -1;
				break;
			// Look around instruction also doesn't consume any
			// inputs but they are more complex as we have to save
			// some information before calling the sub-pattern and
			// restore them after.
			case nfa_Ilook: {
				int old = cap->cnt, tsp = sp;
				if (ins->arg1 == '<') {
					swap(seq_t *, exe->seq, exe->rev);
					tsp = ntok - sp;
				}
				int res = rec(pc + 1, tsp);
				if (ins->arg1 == '<')
					swap(seq_t *, exe->seq, exe->rev);
				cap->cnt = old;
				if (res == -1)
					return -1;
				pc = a2;
				break; }
			// Next the consuming instructions. Each of these assert
			// something on the input and follow a single arc if
			// possible.
			case nfa_Iany:
				if (sp >= ntok)
					return -1;
				pc = a2; sp++;
				break;
			case nfa_Itoken: {
				if (sp >= ntok) return -1;
				const tok_t *tok = &seq->tok[sp];
				if (strcmp(str[a1], tok->raw) != 0)
					return -1;
				pc = a2; sp++;
				break; }
			case nfa_Iregex: {
				if (sp >= ntok) return -1;
				lua_getglobal(L, "string");
				lua_getfield(L, -1, "find");
				lua_pushstring(L, seq->tok[sp].raw);
				lua_pushstring(L, str[a1]);
				lua_call(L, 2, 1);
				int res = lua_isnoneornil(L, -1);
				lua_pop(L, 2);
				if (res) return -1;
				pc = a2; sp++;
				break; }
			case nfa_Itag: {
				if (sp >= ntok) return -1;
				const tok_t *tok = &seq->tok[sp];
				const char  *ref = str[a1];
				int len = -1;
				for (int i = 0; len == -1 && i < tok->ntag; i++)
					if (strcmp(ref, tok->tag[i].str) == 0)
						len = tok->tag[i].len;
				if (len == -1) return -1;
				pc = a2; sp += len;
				break; }
			case nfa_Icall: {
				if (sp >= ntok) return -1;
				lua_getglobal(L, str[a1]);
				lua_pushvalue(L, 2);
				lua_pushinteger(L, sp + 1);
				lua_call(L, 2, 1);
				int res = lua_toboolean(L, -1);
				lua_pop(L, 1);
				if (res == 0) return -1;
				pc = a2; sp++;
				break; }
			// The split instruction who can create new threads
			// meaning in this case making a recursive call. First
			// branch should be taken first to ensure respect of the
			// priority.
			case nfa_Isplit:
				if (a1 != a2) {
					int res = rec(a1, sp);
					if (res != -1)
						return res;
				}
				pc = a2;
				break;
			// And finally, the capture instructions who record the
			// matches as we go
			case nfa_Iopen: {
				if (cap->cnt == cap->size) {
					int sz = cap->size ? cap->size * 2 : 16;
					int as = sz * sizeof(cap->pos[0]);
					void *t = realloc(cap->pos, as);
					if (t == NULL)
						luaL_error(L, "out of memory");
					cap->size = sz;
					cap->pos  = t;
				}
				int n = cap->cnt++;
				cap->pos[n].tag = a1;
				cap->pos[n].beg = sp;
				cap->pos[n].end = -1;
				int res = rec(a2, sp);
				if (res != -1) return res;
				cap->cnt--;
				return -1; }
			case nfa_Iclose: {
				int n = cap->cnt - 1;
				while (n >= 0 && cap->pos[n].end != -1)
					n--;
				if (n < 0)
					luaL_error(L, "internal error");
				cap->pos[n].end = sp;
				int res = rec(a2, sp);
				if (res != -1) return res;
				cap->pos[n].end = -1;
				return -1; }
			// If we go there, there is a big problem. Probably a
			// bug who messed up the code.
			default:
				luaL_error(L, "internal error");
				return -42;
		}
	}
	return -1;
#undef rec
}

/* exe_match:
 *   Run an NFA on a sequence starting from position [sp]. Return -1 if no match
 *   are found, else return the end position of the match and populate the [cap]
 *   array with capture found while matching.
 */
static
int exe_match(lua_State *L, nfa_t *nfa, int sp, cap_t *cap) {
	exe_t exe;
	exe.nfa = nfa;
	exe.seq = lua_touserdata(L, 2);
	exe.rev = lua_touserdata(L, 3);
	exe.cap = cap;
	return exe_run(L, &exe, 1, sp);
}

/*******************************************************************************
 * Patterns
 ******************************************************************************/
typedef struct pat_s pat_t;
struct pat_s {
	nfa_t *nfa;
};

/* patL_new:
 *   Compile and return a new pattern object ready to be applyed on sequence
 *   objects. On problem, raise an error with a meaningfull message (or try to
 *   be).
 */
static
int patL_new(lua_State *L) {
	const char *arg = luaL_checkstring(L, 1);
	lua_settop(L, 1);
	pat_t *pat = lua_newuserdata(L, sizeof(pat_t));
	pat->nfa   = NULL;
	luaL_getmetatable(L, "pat_t");
	lua_setmetatable(L, -2);
	ast_t *ast = ast_parse(L, arg);
	pat->nfa = nfa_compile(ast);
	if (pat->nfa == NULL)
		luaL_error(L, "out of memory");
	lua_settop(L, 2);
	return 1;
}

/* patL_free:
 *   Release all memory used by a pattern object on the C side. This doesn't
 *   free the pattern object itself as it is allocated on the Lua side. This
 *   function should be called only by the Lua garbage collector, it should
 *   never be called directly.
 */
static
int patL_free(lua_State *L) {
	pat_t *pat = luaL_checkudata(L, 1, "pat_t");
	if (pat->nfa != NULL)
		nfa_free(pat->nfa);
	return 0;
}

/* patL_exec:
 *   Execute a compiled pattern on a given sequence and add the matched tags.
 */
static
int patL_exec(lua_State *L) {
	lua_settop(L, 2);
	pat_t *pat = luaL_checkudata(L, 1, "pat_t");
	seq_t *seq = luaL_checkudata(L, 2, "seq_t");
	seq_reverse(L, seq);
	for (int sp = 0; sp < seq->ntok; ) {
		cap_t  cap = {0, 0, NULL};
		int nsp = exe_match(L, pat->nfa, sp, &cap);
		if (nsp == -1)
			break;
		for (int i = 0; i < cap.cnt; i++) {
			const char *tag = pat->nfa->str[cap.pos[i].tag];
			const int   beg = cap.pos[i].beg;
			const int   end = cap.pos[i].end;
			if (beg != end)
				seq_add(L, &seq->tok[beg], tag, end - beg);
		}
		if (nsp > sp) sp = nsp;
		else          sp++;
	}
	lua_pop(L, 1);
	return 1;
}

/* pat_open:
 *   Setup the pattern module in the given Lua state. This mean creating the
 *   meta-table and registering the module function in the table on top of the
 *   stack.
 */
static
void pat_open(lua_State *L) {
	static const luaL_Reg pat_meta[] = {
		{"__gc",   patL_free},
		{"__call", patL_exec},
		{NULL, NULL}};
	static const luaL_Reg pat_method[] = {
		{"exec",   patL_exec},
		{NULL, NULL}};
	luaL_newmetatable(L, "pat_t");
	luaL_setfuncs(L, pat_meta, 0);
	luaL_newlib(L, pat_method);
	lua_pushvalue(L, -1);
	lua_setfield(L, -3, "__index");
	lua_setfield(L, -2, "__metatable");
	lua_pop(L, 1);
	lua_pushcfunction(L, patL_new);
	lua_setfield(L, -2, "pattern");
}

/*******************************************************************************
 * OS toolbox
 ******************************************************************************/
#ifdef DARK_POSIX

#include <unistd.h>
#include <dirent.h>

#ifndef PATH_MAX
  #define PATH_MAX 2048
#endif

/* osxL_getcwd:
 *   Return the current working directory.
 */
static
int osxL_getcwd(lua_State *L) {
	char path[PATH_MAX];
	if (getcwd(path, sizeof(path)) == NULL)
		luaL_error(L, "failed to get current working directory");
	lua_pushstring(L, path);
	return 1;
}

/* osxL_chdir:
 *   Change the current working directory.
 */
static
int osxL_chdir(lua_State *L) {
	const char *path = luaL_checkstring(L, 1);
	if (chdir(path) != 0)
		luaL_error(L, "failed to change current directory");
	return 0;
}

/* osxL_dir:
 *   Return an iterator over the content of a directory.
 */
static
int osxL_dir_it(lua_State *L) {
	DIR **d = lua_touserdata(L, lua_upvalueindex(1));
	if (*d != NULL) {
		while (1) {
			struct dirent *e = readdir(*d);
			if (e == NULL)                break;
			if (!strcmp(e->d_name, "." )) continue;
			if (!strcmp(e->d_name, "..")) continue;
			lua_pushstring(L, e->d_name);
			return 1;
		}
		closedir(*d);
	}
	*d = NULL;
	return 0;
}
static
int osxL_dir_gc(lua_State *L) {
	DIR **d = lua_touserdata(L, 1);
	if (*d != NULL) {
		closedir(*d);
		*d = NULL;
	}
	return 0;
}
static
int osxL_dir(lua_State *L) {
	const char *p = luaL_checkstring(L, 1);
	DIR **d = lua_newuserdata(L, sizeof(DIR *));
	*d = NULL;
	lua_newtable(L);
	lua_pushcfunction(L, osxL_dir_gc);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	*d = opendir(p);
	if (*d == NULL)
		luaL_error(L, "cannot open %s: %s", p, strerror(errno));
	lua_pushcclosure(L, osxL_dir_it, 1);
	return 1;
}

static
void osx_open(lua_State *L) {
	static const luaL_Reg lib[] = {
		{"getcwd", osxL_getcwd},
		{"chdir",  osxL_chdir },
		{"dir",    osxL_dir   },
		{NULL, NULL},
	};
	lua_getglobal(L, "os");
	luaL_setfuncs(L, lib, 0);
	lua_pop(L, 1);
}
#endif

/*******************************************************************************
 * Lua interpreter
 *
 *   The C part of DARK above is exposed as a Lua library that can be compiled
 *   as a loadable module. The open function below will be called by Lua if this
 *   code is compiled as a shared library and 'required' by a Lua script.
 *
 *   DARK can also be compiled as an independant binary who embed the Lua
 *   interpreter. In this case, the code below will be active and take care of
 *   all the needed setup to spawn a new interpreter, open the Lua standard
 *   library and run the main support script.
 *   In this mode, the library is still not automatically loaded but some magic
 *   is done so a require will load it. This allow to use exactly the same code
 *   in both modes.
 ******************************************************************************/

/* darkL_type:
 *   An extended type function who support the new types defined in DARK.
 */
static
int darkL_type(lua_State *L) {
	lua_settop(L, 1);
	     if (luaL_testudata(L, 1, "seq_t")) lua_pushstring(L, "sequence");
	else if (luaL_testudata(L, 1, "mem_t")) lua_pushstring(L, "maxent"  );
	else if (luaL_testudata(L, 1, "pat_t")) lua_pushstring(L, "pattern" );
	else lua_pushstring(L, luaL_typename(L, 1));
	return 1;
}

/* darkL_method:
 *   This is special function who return the table with methods for one of the
 *   DARK Lua objects. It allow the Lua side of DARK to add methods to these
 *   objects written fully in Lua.
 */
static
int darkL_method(lua_State *L) {
	const char *str = luaL_checkstring(L, 1);
	     if (strcmp(str, "sequence") == 0) luaL_getmetatable(L, "seq_t");
	else if (strcmp(str, "maxent")   == 0) luaL_getmetatable(L, "mem_t");
	else if (strcmp(str, "pattern")  == 0) luaL_getmetatable(L, "pat_t");
	else return luaL_error(L, "unknown type %s", str);
	lua_getfield(L, -1, "__metatable");
	return 1;
}

/* luaopen_dark:
 *   DARK module entry point. This is called by lua when module is required
 *   and is responsible to setup all the code exposed by Lost. It only return a
 *   table with all the module contents.
 */
int luaopen_dark(lua_State *L) {
	static const luaL_Reg lib[] = {
		{"method", darkL_method},
		{"type",   darkL_type  },
		{NULL, NULL}};
	luaL_newlib(L, lib);
	lua_pushstring(L, DARK_VERSION);
	lua_setfield(L, -2, "version");
	seq_open(L);
	mem_open(L);
	pat_open(L);
	return 1;
}

#ifndef DARK_SHARED
#include "dark.inc"

/* traceback:
 *   This function is called when an error occur in protected call of a Lua
 *   script. It add debug informations to the error message.
 */
static
int traceback(lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg != NULL) {
		luaL_traceback(L, L, msg, 1);
	} else if (!lua_isnoneornil(L, 1)) {
		if (!luaL_callmeta(L, 1, "__tostring"))
			lua_pushliteral(L, "(no error message)");
	}
	return 1;
}

/* pmain:
 *   The true entry point called in protected environment by 'main'. Here, we
 *   can initialize the Lua state and launch the support code.
 */
static
int pmain(lua_State *L) {
	int    argc = (int    )lua_tointeger (L, 1);
	char **argv = (char **)lua_touserdata(L, 2);
	// We first open the Lua standard libs and the Lost libs, stoping the GC
	// during this step as a little optimization.
	lua_gc(L, LUA_GCSTOP, 0);
	luaL_openlibs(L);
	#ifdef DARK_POSIX
		osx_open(L);
	#endif
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");
	lua_pushcfunction(L, luaopen_dark);
	lua_setfield(L, -2, "dark");
	lua_settop(L, 0);
	lua_gc(L, LUA_GCRESTART, 0);
	// If the first argument start with an '@', it is removed and remaining
	// string is used as the filename for replacement script which will be
	// used instead of the internal one. If there is no filename after the
	// '@', this just mean to enable debugging on the internal script.
	int dbg = 0, ext = 0;
	if (argc > 0 && argv[0][0] == '@') {
		lua_pushcfunction(L, traceback);
		const char *filename = argv[0] + 1;
		if (filename[0] != '\0') {
			if (luaL_loadfile(L, filename))
				lua_error(L);
			ext = 1;
		}
		argc--, argv++;
		dbg = 1;
	}
	if (ext == 0)
		if (luaL_loadbuffer(L, dark_dat, dark_len, "Dark"))
			lua_error(L);
	// We now have the Lua script on top of the stack and perhaps the debug
	// function just below, we can now push the argument and call execute
	// the script.
	lua_checkstack(L, lua_gettop(L) + argc);
	for (int a = 0; a < argc; a++)
		lua_pushstring(L, argv[a]);
	if (lua_pcall(L, argc, 0, dbg))
		lua_error(L);
	// Cleanup everything and exit the protected environment, this is not
	// needed but as in the toilet you have to leave things in the state you
	// want them when you come back...
	lua_settop(L, 0);
	lua_gc(L, LUA_GCCOLLECT, 0);
	return 0;
}

/* main:
 *   Main will just create the Lua state and jump into a protected environment.
 *   Execution will continue in the 'pmain' where any error can be catch by Lua
 *   and returned here.
 */
int main(int argc, char *argv[argc]) {
	lua_State *L = luaL_newstate();
	if (L == NULL) {
		fprintf(stderr, "error: cannot create Lua state\n");
		return EXIT_FAILURE;
	}
	lua_pushcfunction(L, &pmain);
	lua_pushinteger(L, argc - 1);
	lua_pushlightuserdata(L, argv + 1);
	int res = lua_pcall(L, 2, 1, 0);
	if (res != 0) {
		const char *msg = lua_tostring(L, -1);
		if (msg != NULL)
			fprintf(stderr, "error: %s\n", msg);
		else
			fprintf(stderr, "error: unknown error\n");
		lua_close(L);
		return EXIT_FAILURE;
	}
	res = lua_toboolean(L, -1);
	lua_close(L);
	return res ? EXIT_SUCCESS : EXIT_FAILURE;
}

#endif

/*******************************************************************************
 * This is the end...
 ******************************************************************************/

