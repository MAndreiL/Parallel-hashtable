#ifndef _HASHCPU_
#define _HASHCPU_

#include <vector>

using namespace std;

typedef struct Pair {
	unsigned int key;
	unsigned int value;
} Pair;


/**
 * Class GpuHashTable to implement functions
 */
class GpuHashTable
{
	public:
		GpuHashTable(int size);
		void reshape(int sizeReshape);

		bool insertBatch(int *keys, int* values, int numKeys);
		int* getBatch(int* key, int numItems);

		~GpuHashTable();

	private:
		Pair *entries;
		unsigned int table_len;
		unsigned int inserted_keys;
};

#endif
