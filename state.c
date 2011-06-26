/*
 * Copyright (C) 2011 Andrea Mazzoleni
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "portable.h"

#include "elem.h"
#include "state.h"
#include "util.h"

void state_init(struct snapraid_state* state)
{
	state->verbose = 0;
	state->gui = 0;
	state->force_zero = 0;
	state->force_empty = 0;
	state->expect_unrecoverable = 0;
	state->expect_recoverable = 0;
	state->need_write = 0;
	state->block_size = 256 * 1024; /* default 256 KiB */
	state->parity[0] = 0;
	state->qarity[0] = 0;
	state->level = 1; /* default is the lowest protection */
	state->hash = HASH_MURMUR3; /* default is the fastest */
	tommy_array_init(&state->diskarr);
	tommy_list_init(&state->contentlist);
	tommy_list_init(&state->filterlist);
}

void state_done(struct snapraid_state* state)
{
	unsigned i;

	for(i=0;i<tommy_array_size(&state->diskarr);++i)
		disk_free(tommy_array_get(&state->diskarr, i));
	tommy_array_done(&state->diskarr);
	tommy_list_foreach(&state->contentlist, (tommy_foreach_func*)content_free);
	tommy_list_foreach(&state->filterlist, (tommy_foreach_func*)filter_free);
}

void state_config(struct snapraid_state* state, const char* path, int verbose, int gui, int force_zero, int force_empty, int expect_unrecoverable, int expect_recoverable)
{
	STREAM* f;
	unsigned line;
	unsigned content_count;

	state->verbose = verbose;
	state->gui = gui;
	state->force_zero = force_zero;
	state->force_empty = force_empty;
	state->expect_unrecoverable = expect_unrecoverable;
	state->expect_recoverable = expect_recoverable;

	if (state->gui) {
		fprintf(stderr, "version:%s\n", PACKAGE_VERSION);
		fprintf(stderr, "conf:%s\n", path);
		fflush(stderr);
	}

	f = sopen(path);
	if (!f) {
		if (errno == ENOENT) {
			fprintf(stderr, "No configuration file found at '%s'\n", path);
		} else if (errno == EACCES) {
			fprintf(stderr, "You do not have rights to access the configuration file '%s'\n", path);
		} else {
			fprintf(stderr, "Error opening the configuration file '%s'. %s.\n", path, strerror(errno));
		}
		exit(EXIT_FAILURE);
	}

	line = 1;
	content_count = 0;
	while (1) {
		char tag[PATH_MAX];
		char buffer[PATH_MAX];
		int ret;
		int c;

		/* skip initial spaces */
		sgetspace(f);

		/* read the command */
		ret = sgettok(f, tag, sizeof(tag));
		if (ret != 0) {
			fprintf(stderr, "Error reading the configuration file '%s' at line %u\n", path, line);
			exit(EXIT_FAILURE);
		}

		/* skip spaces after the command */
		sgetspace(f);

		if (strcmp(tag, "block_size") == 0) {
			ret = sgetu32(f, &state->block_size);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'block_size' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
			if (state->block_size < 1) {
				fprintf(stderr, "Too small 'block_size' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
			if (state->block_size > 16*1024) {
				fprintf(stderr, "Too big 'block_size' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
			/* check if it's a power of 2 */
			if ((state->block_size & (state->block_size - 1)) != 0) {
				fprintf(stderr, "Not power of 2 'block_size' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
			state->block_size *= 1024;
		} else if (strcmp(tag, "parity") == 0) {
			if (*state->parity) {
				fprintf(stderr, "Multiple 'parity' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'parity' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			pathcpy(state->parity, sizeof(state->parity), buffer);
		} else if (strcmp(tag, "q-parity") == 0) {
			if (*state->qarity) {
				fprintf(stderr, "Multiple 'q-parity' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'q-parity' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			pathcpy(state->qarity, sizeof(state->qarity), buffer);
			state->level = 2;
		} else if (strcmp(tag, "content") == 0) {
			struct snapraid_content* content;

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'content' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			content = content_alloc(buffer);

			tommy_list_insert_tail(&state->contentlist, &content->node, content);
			++content_count;
		} else if (strcmp(tag, "disk") == 0) {
			char dir[PATH_MAX];

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'disk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			sgetspace(f);

			ret = sgettok(f, dir, sizeof(dir));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'disk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			tommy_array_insert(&state->diskarr, disk_alloc(buffer, dir));
		} else if (strcmp(tag, "exclude") == 0) {
			struct snapraid_filter* filter;

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'exclude' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			filter = filter_alloc(-1, buffer);
			if (!filter) {
				fprintf(stderr, "Invalid 'exclude' specification '%s' in '%s' at line %u\n", buffer, path, line);
				exit(EXIT_FAILURE);
			}
			tommy_list_insert_tail(&state->filterlist, &filter->node, filter);
		} else if (strcmp(tag, "include") == 0) {
			struct snapraid_filter* filter;

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'include' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			filter = filter_alloc(1, buffer);
			if (!filter) {
				fprintf(stderr, "Invalid 'include' specification '%s' in '%s' at line %u\n", buffer, path, line);
				exit(EXIT_FAILURE);
			}
			tommy_list_insert_tail(&state->filterlist, &filter->node, filter);
		} else if (tag[0] == 0) {
			/* allow empty lines */
		} else if (tag[0] == '#') {
			ret = sgetline(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid comment in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
		} else {
			fprintf(stderr, "Invalid command '%s' in '%s' at line %u\n", tag, path, line);
			exit(EXIT_FAILURE);
		}

		/* skip final spaces */
		sgetspace(f);

		/* next line */
		c = sgeteol(f);
		if (c == EOF) {
			break;
		}
		if (c != '\n') {
			fprintf(stderr, "Extra data in '%s' at line %u\n", path, line);
			exit(EXIT_FAILURE);
		}
		++line;
	}

	if (serror(f)) {
		fprintf(stderr, "Error reading the configuration file '%s' at line %u\n", path, line);
		exit(EXIT_FAILURE);
	}

	sclose(f);

	if (state->parity[0] == 0) {
		fprintf(stderr, "No 'parity' specification in '%s'\n", path);
		exit(EXIT_FAILURE);
	}
	if (content_count == 0) {
		fprintf(stderr, "No 'content' specification in '%s'\n", path);
		exit(EXIT_FAILURE);
	}
	if (state->qarity[0] != 0 && content_count < 2) {
		fprintf(stderr, "With 'q-parity' you must have at least two 'content' specifications in '%s'\n", path);
		exit(EXIT_FAILURE);
	}

	if (state->gui) {
		unsigned i;
		fprintf(stderr, "blocksize:%u\n", state->block_size);
		for(i=0;i<tommy_array_size(&state->diskarr);++i) {
			struct snapraid_disk* disk = tommy_array_get(&state->diskarr, i);
			fprintf(stderr, "disk:%s:%s\n", disk->name, disk->dir);
		}
		if (state->qarity[0] != 0)
			fprintf(stderr, "mode:raid6\n");
		else
			fprintf(stderr, "mode:raid5\n");
		fprintf(stderr, "parity:%s\n", state->parity);
		if (state->qarity[0] != 0)
			fprintf(stderr, "qarity:%s\n", state->qarity);
		fflush(stderr);
	}
}

void state_read(struct snapraid_state* state)
{
	STREAM* f;
	char path[PATH_MAX];
	struct snapraid_disk* disk;
	struct snapraid_file* file;
	block_off_t blockidx;
	unsigned line;
	unsigned count_file;
	unsigned count_block;
	tommy_node* node;

	count_file = 0;
	count_block = 0;

	/* iterate over all the available content files and load the first one present */
	f = 0;
	node = tommy_list_head(&state->contentlist);
	while (node) {
		struct snapraid_content* content = node->data;
		pathcpy(path, sizeof(path), content->content);

		if (state->gui) {
			fprintf(stderr, "content:%s\n", path);
			fflush(stderr);
		}
		printf("Loading state from %s...\n", path);

		f = sopen(path);
		if (f != 0) {
			/* if openend stop the search */
			break;
		} else {
			/* if it's real error of an existing file, abort */
			if (errno != ENOENT) {
				fprintf(stderr, "Error opening the content file '%s'\n", path);
				exit(EXIT_FAILURE);
			}

			/* otherwise continue */
			if (node->next) {
				fprintf(stderr, "Not found, trying with another copy...\n");
			}
		}

		node = node->next;
	}

	/* if not found, assume empty */
	if (!f) {
		fprintf(stderr, "No content file found. Assuming empty.\n");
		return;
	}

	/* start with a MD5 default. */
	/* it's for compatibility with version 1.0 where MD5 was implicit. */
	state->hash = HASH_MD5;

	disk = 0;
	file = 0;
	line = 1;
	blockidx = 0;

	while (1) {
		char buffer[PATH_MAX];
		char tag[PATH_MAX];
		int ret;
		int c;

		/* read the command */
		ret = sgettok(f, tag, sizeof(tag));
		if (ret != 0) {
			fprintf(stderr, "Error reading the configuration file '%s' at line %u\n", path, line);
			exit(EXIT_FAILURE);
		}

		/* skip only one space if present */
		c = sgetc(f);
		if (c != ' ') {
			sungetc(c, f);
		}

		if (strcmp(tag, "blk") == 0 || strcmp(tag, "inv") == 0) {
			/* "blk"/"inv" command */
			block_off_t v_pos;
			struct snapraid_block* block;

			if (!file) {
				fprintf(stderr, "Unexpected 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgetu32(f, &v_pos);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			if (blockidx >= file->blockmax) {
				fprintf(stderr, "Internal inconsistency in 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			block = &file->blockvec[blockidx];

			if (block->parity_pos != POS_INVALID) {
				fprintf(stderr, "Internal inconsistency in 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			block->parity_pos = v_pos;

			/* check if we are at the end of the line */
			c = sgeteol(f);
			if (c == '\n') {
				/* no hash present */
				sungetc(c, f);
			} else {
				if (c != ' ') {
					fprintf(stderr, "Invalid 'blk' specification in '%s' at line %u\n", path, line);
					exit(EXIT_FAILURE);
				}

				/* set the hash only if present */
				ret = sgethex(f, block->hash, HASH_SIZE);
				if (ret != 0) {
					fprintf(stderr, "Invalid 'blk' specification in '%s' at line %u\n", path, line);
					exit(EXIT_FAILURE);
				}

				block_flag_set(block, BLOCK_HAS_HASH);
			}

			/* set the parity only if present */
			if (strcmp(tag, "blk") == 0)
				block_flag_set(block, BLOCK_HAS_PARITY);

			/* parity implies hash */
			if (block_flag_has(block, BLOCK_HAS_PARITY) && !block_flag_has(block, BLOCK_HAS_HASH)) {
				fprintf(stderr, "Internal inconsistency in 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			/* insert the block in the block array */
			tommy_array_grow(&disk->blockarr, block->parity_pos + 1);
			tommy_array_set(&disk->blockarr, block->parity_pos, block);

			/* check for termination of the block list */
			++blockidx;
			if (blockidx == file->blockmax) {
				file = 0;
				disk = 0;
			}

			/* stat */
			++count_block;
		} else if (strcmp(tag, "file") == 0) {
			/* file */
			char buffer[PATH_MAX];
			char sub[PATH_MAX];
			uint64_t v_size;
			uint64_t v_mtime;
			uint64_t v_inode;
			unsigned i;

			if (file) {
				fprintf(stderr, "Missing 'blk' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			c = sgetc(f);
			if (c != ' ') {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgetu64(f, &v_size);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			c = sgetc(f);
			if (c != ' ') {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgetu64(f, &v_mtime);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			c = sgetc(f);
			if (c != ' ') {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgetu64(f, &v_inode);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			c = sgetc(f);
			if (c != ' ') {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			ret = sgetline(f, sub, sizeof(sub));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			if (!*sub) {
				fprintf(stderr, "Invalid 'file' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			/* find the disk */
			for(i=0;i<tommy_array_size(&state->diskarr);++i) {
				disk = tommy_array_get(&state->diskarr, i);
				if (strcmp(disk->name, buffer) == 0)
					break;
			}
			if (i == tommy_array_size(&state->diskarr)) {
				fprintf(stderr, "Disk named '%s' not found in '%s' at line %u\n", buffer, path, line);
				exit(EXIT_FAILURE);
			}

			/* allocate the file */
			file = file_alloc(state->block_size, sub, v_size, v_mtime, v_inode);

			/* insert the file in the file containers */
			tommy_hashdyn_insert(&disk->inodeset, &file->nodeset, file, file_inode_hash(file->inode));
			tommy_list_insert_tail(&disk->filelist, &file->nodelist, file);

			/* start the block allocation of the file */
			blockidx = 0;

			/* check for empty file */
			if (blockidx == file->blockmax) {
				file = 0;
				disk = 0;
			}

			/* stat */
			++count_file;
		} else if (strcmp(tag, "checksum") == 0) {
			ret = sgettok(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid 'checksum' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			if (strcmp(buffer, "md5") == 0) {
				state->hash = HASH_MD5;
			} else if (strcmp(buffer, "murmur3") == 0) {
				state->hash = HASH_MURMUR3;
			} else {
				fprintf(stderr, "Invalid 'checksum' specification '%s' in '%s' at line %u\n", buffer, path, line);
				exit(EXIT_FAILURE);
			}
		} else if (strcmp(tag, "blksize") == 0) {
			block_off_t blksize;

			ret = sgetu32(f, &blksize);
			if (ret != 0) {
				fprintf(stderr, "Invalid 'blksize' specification in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}

			if (blksize != state->block_size) {
				fprintf(stderr, "Mismatching 'blksize' and 'block_size' specification in '%s' at line %u\n", path, line);
				fprintf(stderr, "Please restore the 'block_size' value in the configuration file to '%u'\n", blksize / 1024);
				exit(EXIT_FAILURE);
			}
		} else if (tag[0] == 0) {
			/* allow empty lines */
			sgetspace(f);
		} else if (tag[0] == '#') {
			ret = sgetline(f, buffer, sizeof(buffer));
			if (ret != 0) {
				fprintf(stderr, "Invalid comment in '%s' at line %u\n", path, line);
				exit(EXIT_FAILURE);
			}
		} else {
			fprintf(stderr, "Invalid command '%s' in '%s' at line %u\n", tag, path, line);
			exit(EXIT_FAILURE);
		}

		/* next line */
		c = sgeteol(f);
		if (c == EOF) {
			break;
		}
		if (c != '\n') {
			fprintf(stderr, "Extra data in '%s' at line %u\n", path, line);
			exit(EXIT_FAILURE);
		}
		++line;
	}

	if (serror(f)) {
		fprintf(stderr, "Error reading the content file '%s' at line %u\n", path, line);
		exit(EXIT_FAILURE);
	}

	if (file) {
		fprintf(stderr, "Missing 'blk' specification in '%s' at line %u\n", path, line);
		exit(EXIT_FAILURE);
	}

	sclose(f);

	if (state->verbose) {
		printf("\tfile %u\n", count_file);
		printf("\tblock %u\n", count_block);
	}
}

static void state_write_one(struct snapraid_state* state, const char* path, unsigned* out_count_file, unsigned* out_count_block)
{
	FILE* f;
	char tmp[PATH_MAX];
	unsigned count_file;
	unsigned count_block;
	unsigned i;
	int ret;

	count_file = 0;
	count_block = 0;

	printf("Saving state to %s...\n", path);

	pathprint(tmp, sizeof(tmp), "%s.tmp", path);
	f = fopen(tmp, "wt");
	if (!f) {
		fprintf(stderr, "Error opening for writing the content file '%s'\n", tmp);
		exit(EXIT_FAILURE);
	}

	ret = fprintf(f, "blksize %u\n", state->block_size);
	if (ret < 0) {
		fprintf(stderr, "Error writing the content file '%s' in fprintf(). %s.\n", tmp, strerror(errno));
		exit(EXIT_FAILURE);
	}

	ret = fprintf(f, "checksum %s\n", state->hash == HASH_MD5 ? "md5" : "murmur3");
	if (ret < 0) {
		fprintf(stderr, "Error writing the content file '%s' in fprintf(). %s.\n", tmp, strerror(errno));
		exit(EXIT_FAILURE);
	}

	/* for each disk */
	for(i=0;i<tommy_array_size(&state->diskarr);++i) {
		tommy_node* j;
		struct snapraid_disk* disk = tommy_array_get(&state->diskarr, i);

		/* for each file */
		for(j=disk->filelist;j!=0;j=j->next) {
			block_off_t k;
			struct snapraid_file* file = j->data;
			uint64_t size;
			uint64_t mtime;
			uint64_t inode;

			size = file->size;
			mtime = file->mtime;
			inode = file->inode,

			ret = fprintf(f,"file %s %"PRIu64" %"PRIu64" %"PRIu64" %s\n", disk->name, size, mtime, inode, file->sub);
			if (ret < 0) {
				fprintf(stderr, "Error writing the content file '%s' in fprintf(). %s.\n", tmp, strerror(errno));
				exit(EXIT_FAILURE);
			}

			/* for each block */
			for(k=0;k<file->blockmax;++k) {
				struct snapraid_block* block = &file->blockvec[k];
				const char* tag;

				if (block_flag_has(block, BLOCK_HAS_PARITY)) {
					tag = "blk";
				} else {
					tag = "inv";
				}

				if (block_flag_has(block, BLOCK_HAS_HASH)) {
					char s_hash[HASH_SIZE*2+1];
					strenchex(s_hash, block->hash, HASH_SIZE);
					s_hash[HASH_SIZE*2] = 0;
					ret = fprintf(f, "%s %u %s\n", tag, block->parity_pos, s_hash);
				} else {
					ret = fprintf(f, "%s %u\n", tag, block->parity_pos);
				}
				if (ret < 0) {
					fprintf(stderr, "Error writing the content file '%s' in fprintf(). %s.\n", tmp, strerror(errno));
					exit(EXIT_FAILURE);
				}

				++count_block;
			}

			++count_file;
		}
	}

	/* Use the sequence fflush() -> fsync() -> fclose() -> rename() to ensure */
	/* than even in a system crash event we have one valid copy of the file. */

	if (fflush(f) != 0) {
		fprintf(stderr, "Error writing the content file '%s', in fflush(). %s.\n", tmp, strerror(errno));
		exit(EXIT_FAILURE);
	}

#if HAVE_FSYNC
	if (fsync(fileno(f)) != 0) {
		fprintf(stderr, "Error writing the content file '%s' in fsync(). %s.\n", tmp, strerror(errno));
		exit(EXIT_FAILURE);
	}
#endif

	if (fclose(f) != 0) {
		fprintf(stderr, "Error writing the content file '%s' in close(). %s.\n", tmp, strerror(errno));
		exit(EXIT_FAILURE);
	}

	if (rename(tmp, path) != 0) {
		fprintf(stderr, "Error renaming the content file '%s' to '%s' in rename(). %s.\n", tmp, path, strerror(errno));
		exit(EXIT_FAILURE);
	}

	if (out_count_file)
		*out_count_file = count_file;
	if (out_count_block)
		*out_count_block = count_block;
}

void state_write(struct snapraid_state* state)
{
	unsigned count_file;
	unsigned count_block;
	tommy_node* node;

	count_file = 0;
	count_block = 0;

	node = tommy_list_head(&state->contentlist);
	while (node) {
		struct snapraid_content* content = node->data;
		state_write_one(state, content->content, &count_file, &count_block);
		node = node->next;
	}

	if (state->verbose) {
		printf("\tfile %u\n", count_file);
		printf("\tblock %u\n", count_block);
	}
}

void state_filter(struct snapraid_state* state, tommy_list* filterlist)
{
	unsigned i;

	/* if no filter, include all */
	if (tommy_list_empty(filterlist))
		return;

	printf("Filtering...\n");

	if (state->verbose) {
		tommy_node* k;
		for(k=tommy_list_head(filterlist);k!=0;k=k->next) {
			struct snapraid_filter* filter = k->data;
			printf("\t%s", filter->pattern);
			if (filter->is_dir)
				printf("/");
			printf("\n");
		}
	}

	/* for each disk */
	for(i=0;i<tommy_array_size(&state->diskarr);++i) {
		tommy_node* j;
		struct snapraid_disk* disk = tommy_array_get(&state->diskarr, i);

		/* for each file */
		for(j=tommy_list_head(&disk->filelist);j!=0;j=j->next) {
			struct snapraid_file* file = j->data;

			if (filter_path(filterlist, file->sub, 0) != 0) {
				file_flag_set(file, FILE_IS_EXCLUDED);
			}

			if (state->verbose && !file_flag_has(file, FILE_IS_EXCLUDED)) {
				printf("Processing file '%s'\n", file->sub);
			}
		}
	}
}

void state_progress_begin(struct snapraid_state* state, block_off_t blockstart, block_off_t blockmax, block_off_t countmax)
{
	if (state->gui) {
		fprintf(stderr,"run:begin:%u:%u:%u\n", blockstart, blockmax, countmax);
		fflush(stderr);
	} else {
		time_t now;

		now = time(0);

		state->progress_start = now;
		state->progress_last = now;
	}
}

void state_progress_end(struct snapraid_state* state, block_off_t countpos, block_off_t countmax, data_off_t countsize)
{
	if (state->gui) {
		fprintf(stderr, "run:end\n");
		fflush(stderr);
	} else {
		unsigned countsize_MiB = (countsize + 1024*1024 - 1) / (1024*1024);

		if (countmax)
			printf("%u%% completed, %u MiB processed\n", countpos * 100 / countmax, countsize_MiB);
		else
			printf("Nothing to do\n");
	}
}

#define PROGRESS_CLEAR "          "

int state_progress(struct snapraid_state* state, block_off_t blockpos, block_off_t countpos, block_off_t countmax, data_off_t countsize)
{
	if (state->gui) {
		fprintf(stderr, "run:pos:%u:%u:\n", blockpos, countpos);
		fflush(stderr);
	} else {
		time_t now;

		now = time(0);

		if (state->progress_last != now) {
			time_t delta = now - state->progress_start;

			printf("%u%%, %u MiB", countpos * 100 / countmax, (unsigned)(countsize / (1024*1024)));

			if (delta != 0) {
				printf(", %u MiB/s", (unsigned)(countsize / (1024*1024) / delta));
			}

			if (delta > 5 && countpos > 0) {
				unsigned m, h;
				data_off_t todo = countmax - countpos;

				m = todo * delta / (60 * countpos);

				h = m / 60;
				m = m % 60;

				printf(", %u:%02u ETA%s", h, m, PROGRESS_CLEAR);
			}
			printf("\r");
			fflush(stdout);
			state->progress_last = now;
		}
	}

	/* stop if requested */
	if (global_interrupt) {
		if (!state->gui) {
			printf("\n");
			printf("Stopping for interruption at block %u\n", blockpos);
		}
		return 1;
	}

	return 0;
}

