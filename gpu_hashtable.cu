#include <iostream>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctime>
#include <sstream>
#include <string>
#include "test_map.hpp"
#include "gpu_hashtable.hpp"

using namespace std;

/*
Allocate CUDA memory only through glbGpuAllocator
cudaMalloc -> glbGpuAllocator->_cudaMalloc
cudaMallocManaged -> glbGpuAllocator->_cudaMallocManaged
cudaFree -> glbGpuAllocator->_cudaFree
*/

__global__ void device_reshape(Pair *old_entries, unsigned int old_size, Pair *new_entries, unsigned int new_size) {
	unsigned int idx = threadIdx.x + blockIdx.x * blockDim.x;
	if (idx >= old_size || old_entries[idx].key == KEY_INVALID)
		return;
	unsigned int hash = (((unsigned long long)(old_entries[idx].key) * 985463) % 2865417259) % new_size;
	unsigned int initial_hash = hash;
    while (true) {
        unsigned int prev = atomicCAS(&new_entries[hash].key, KEY_INVALID, old_entries[idx].key);
        if (prev == KEY_INVALID) {
			new_entries[hash].value = old_entries[idx].value;
            return;
		} else {
    		hash = (hash + 1) % new_size;
			if (hash == initial_hash)
				return;
		}
    }
}

__global__ void insert(Pair *entries, unsigned int table_len, unsigned int *keys, unsigned int* values, unsigned int numKeys, unsigned int *inserted_keys) {
	unsigned int idx = threadIdx.x + blockIdx.x * blockDim.x;
	if (idx >= numKeys)
		return;
	unsigned int hash = (((long long)(keys[idx]) * 985463) % 2865417259) % table_len;
	unsigned int initial_hash = hash;
    while (true) {
        unsigned int prev = atomicCAS(&entries[hash].key, KEY_INVALID, keys[idx]);
        if (prev == KEY_INVALID) {
			entries[hash].value = values[idx];
			atomicInc(inserted_keys, INT_MAX);
            return;
		} else if (prev == keys[idx]) {
			entries[hash].value = values[idx];
			return;
		}
        hash = (hash + 1) % table_len;
		if (hash == initial_hash)
			return;
    }
}

__global__ void get(Pair *entries, unsigned int table_len, unsigned int *keys, unsigned int numKeys, unsigned int* values) {
	unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx >= numKeys)
		return;
	unsigned int hash = (((long long)(keys[idx]) * 985463) % 2865417259) % table_len;
	unsigned int initial_hash = hash;
	while (true) {
		if (entries[hash].key == keys[idx]) {
			values[idx] = entries[hash].value;
			return;
		}
        hash = (hash + 1) % table_len;
		if (hash == initial_hash)
			return;
	}
}

/**
 * Function constructor GpuHashTable
 * Performs init
 * Example on using wrapper allocators _cudaMalloc and _cudaFree
 */
GpuHashTable::GpuHashTable(int size) {
	glbGpuAllocator->_cudaMallocManaged((void **)&this->entries, sizeof(Pair) * size);
	this->inserted_keys = 0;
	this->table_len = size;
	cudaMemset(this->entries, 0, size * sizeof(Pair));
}

/**
 * Function desctructor GpuHashTable
 */
GpuHashTable::~GpuHashTable() {
	glbGpuAllocator->_cudaFree(this->entries);
}

/**
 * Function reshape
 * Performs resize of the hashtable based on load factor
 */
void GpuHashTable::reshape(int numBucketsReshape) {
	Pair *old_entries = this->entries;
	unsigned int old_size = this->table_len;
	unsigned int numBlocks = old_size / 256;
	glbGpuAllocator->_cudaMallocManaged((void **)&this->entries, sizeof(Pair) * numBucketsReshape);
	cudaMemset(this->entries, 0, numBucketsReshape * sizeof(Pair));
	this->table_len = numBucketsReshape;
	if (old_size % 256 != 0)
		numBlocks++;
	device_reshape<<<numBlocks, 256>>>(old_entries, old_size, this->entries, this->table_len);
	cudaDeviceSynchronize();
	glbGpuAllocator->_cudaFree(old_entries);
	return;
}

/**
 * Function insertBatch
 * Inserts a batch of key:value, using GPU and wrapper allocators
 */
bool GpuHashTable::insertBatch(int *keys, int* values, int numKeys) {
	if (numKeys == 0)
		return false;
	if ((float)(inserted_keys + numKeys) / table_len >= 0.8f)
    reshape(table_len * 1.5f);
	unsigned int *values_GPU;
	unsigned int *keys_GPU;
	unsigned int *inserted_keys_GPU;
	unsigned int numBlocks = numKeys / 256;
	glbGpuAllocator->_cudaMalloc((void **)&values_GPU, sizeof(unsigned int) * numKeys);
	cudaMemcpy(values_GPU, values, sizeof(unsigned int) * numKeys, cudaMemcpyHostToDevice);
	glbGpuAllocator->_cudaMalloc((void **)&keys_GPU, sizeof(unsigned int) * numKeys);
	cudaMemcpy(keys_GPU, keys, sizeof(unsigned int) * numKeys, cudaMemcpyHostToDevice);
	glbGpuAllocator->_cudaMallocManaged((void **)&inserted_keys_GPU, sizeof(unsigned int));
	*inserted_keys_GPU = 0;
	if (numKeys % 256 != 0)
		numBlocks++;
	insert<<<numBlocks, 256>>>(this->entries, this->table_len, keys_GPU, values_GPU, numKeys, inserted_keys_GPU);
	cudaDeviceSynchronize();
	this->inserted_keys += *inserted_keys_GPU;
	glbGpuAllocator->_cudaFree(values_GPU);
	glbGpuAllocator->_cudaFree(keys_GPU);
	glbGpuAllocator->_cudaFree(inserted_keys_GPU);
	return true;
}

/**
 * Function getBatch
 * Gets a batch of key:value, using GPU
 */
int* GpuHashTable::getBatch(int* keys, int numKeys) {
	if (numKeys == 0)
		return NULL;
	unsigned int *values_GPU;
	unsigned int *keys_GPU;
	unsigned int blocks = numKeys / 256;
	unsigned int *values_RAM = (unsigned int *)malloc(sizeof(unsigned int) * numKeys);
	glbGpuAllocator->_cudaMallocManaged((void **)&values_GPU, sizeof(unsigned int) * numKeys);
	glbGpuAllocator->_cudaMalloc((void **)&keys_GPU, sizeof(unsigned int) * numKeys);
	cudaMemcpy(keys_GPU, keys, sizeof(unsigned int) * numKeys, cudaMemcpyHostToDevice);
	if (numKeys % 256 != 0)
		blocks++;
	get<<<blocks, 256>>>(this->entries, this->table_len, keys_GPU, numKeys, values_GPU);
	cudaDeviceSynchronize();
	cudaMemcpy(values_RAM, values_GPU, sizeof(unsigned int) * numKeys, cudaMemcpyDeviceToHost);
	glbGpuAllocator->_cudaFree(values_GPU);
	glbGpuAllocator->_cudaFree(keys_GPU);
	return (int *)values_RAM;
}
