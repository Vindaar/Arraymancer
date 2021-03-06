# Copyright 2017 the Arraymancer contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Note: Maximum number of threads per block is
# 1024 on Pascal GPU, i.e. 32 warps of 32 threads


# Important CUDA optimization
# To loop over each element of an array with arbitrary length
# use grid-strides for loop: https://devblogs.nvidia.com/parallelforall/cuda-pro-tip-write-flexible-kernels-grid-stride-loops/
#
# Avoid branching in the same warp (32 threads), otherwise it reverts to serial execution.
# "idx < length" can be converted to "idx = max( idx, 0); idx = min( idx, length);"
# for example. (Beware of aliasing)

# TODO, use an on-device struct to store, shape, strides, offset
# And pass arguments via a struct pointer to limite register pressure

{.emit:["""
  template<typename T, typename Op>
  __global__ void cuda_apply2(const int rank,
                              const int len,
                              const int *  __restrict__ dst_shape,
                              const int *  __restrict__ dst_strides,
                              const int dst_offset,
                              T * __restrict__ dst_data,
                              Op f,
                              const int *  __restrict__ src_shape,
                              const int *  __restrict__ src_strides,
                              const int src_offset,
                              const T * __restrict__ src_data){

    for (int elemID = blockIdx.x * blockDim.x + threadIdx.x;
         elemID < len;
         elemID += blockDim.x * gridDim.x) {

      // ## we can't instantiate the variable outside the loop
      // ## each threads will store its own in parallel
      const int dst_real_idx = cuda_getIndexOfElementID(
                               rank,
                               dst_shape,
                               dst_strides,
                               dst_offset,
                               elemID);

      const int src_real_idx = cuda_getIndexOfElementID(
                               rank,
                               src_shape,
                               src_strides,
                               src_offset,
                               elemID);

      f(&dst_data[dst_real_idx], &src_data[src_real_idx]);
    }
  }
"""].}


{.emit:["""
  template<typename T, typename Op>
  __global__ void cuda_apply3(const int rank,
                              const int len,
                              const int *  __restrict__ dst_shape,
                              const int *  __restrict__ dst_strides,
                              const int dst_offset,
                              T * __restrict__ dst_data,
                              const int *  __restrict__ A_shape,
                              const int *  __restrict__ A_strides,
                              const int A_offset,
                              const T * __restrict__ A_data,
                              Op f,
                              const int *  __restrict__ B_shape,
                              const int *  __restrict__ B_strides,
                              const int B_offset,
                              const T * __restrict__ B_data){

    for (int elemID = blockIdx.x * blockDim.x + threadIdx.x;
         elemID < len;
         elemID += blockDim.x * gridDim.x) {

      // ## we can't instantiate the variable outside the loop
      // ## each threads will store its own in parallel
      const int dst_real_idx = cuda_getIndexOfElementID(
                               rank,
                               dst_shape,
                               dst_strides,
                               dst_offset,
                               elemID);

      const int A_real_idx = cuda_getIndexOfElementID(
                               rank,
                               A_shape,
                               A_strides,
                               A_offset,
                               elemID);

      const int B_real_idx = cuda_getIndexOfElementID(
                               rank,
                               B_shape,
                               B_strides,
                               B_offset,
                               elemID);

      f(&dst_data[dst_real_idx], &A_data[A_real_idx], &B_data[B_real_idx]);
    }
  }
"""].}

{.emit:["""
  template<typename T, typename Op>
  __global__ void cuda_apply_rscal(const int rank,
                                  const int len,
                                  const int *  __restrict__ dst_shape,
                                  const int *  __restrict__ dst_strides,
                                  const int dst_offset,
                                  T * __restrict__ dst_data,
                                  const int *  __restrict__ src_shape,
                                  const int *  __restrict__ src_strides,
                                  const int src_offset,
                                  const T * __restrict__ src_data,
                                  Op f,
                                  const T beta){

    for (int elemID = blockIdx.x * blockDim.x + threadIdx.x;
         elemID < len;
         elemID += blockDim.x * gridDim.x) {

      // ## we can't instantiate the variable outside the loop
      // ## each threads will store its own in parallel
      const int dst_real_idx = cuda_getIndexOfElementID(
                               rank,
                               dst_shape,
                               dst_strides,
                               dst_offset,
                               elemID);

      const int src_real_idx = cuda_getIndexOfElementID(
                               rank,
                               src_shape,
                               src_strides,
                               src_offset,
                               elemID);

      f(&dst_data[dst_real_idx], &src_data[src_real_idx], beta);
    }
  }
"""].}


{.emit:["""
  template<typename T, typename Op>
  __global__ void cuda_apply_lscal(const int rank,
                                  const int len,
                                  const int *  __restrict__ dst_shape,
                                  const int *  __restrict__ dst_strides,
                                  const int dst_offset,
                                  T * __restrict__ dst_data,
                                  const T alpha,
                                  Op f,
                                  const int *  __restrict__ src_shape,
                                  const int *  __restrict__ src_strides,
                                  const int src_offset,
                                  const T * __restrict__ src_data){

    for (int elemID = blockIdx.x * blockDim.x + threadIdx.x;
         elemID < len;
         elemID += blockDim.x * gridDim.x) {

      // ## we can't instantiate the variable outside the loop
      // ## each threads will store its own in parallel
      const int dst_real_idx = cuda_getIndexOfElementID(
                               rank,
                               dst_shape,
                               dst_strides,
                               dst_offset,
                               elemID);

      const int src_real_idx = cuda_getIndexOfElementID(
                               rank,
                               src_shape,
                               src_strides,
                               src_offset,
                               elemID);

      f(&dst_data[dst_real_idx], alpha, &src_data[src_real_idx]);
    }
  }
"""].}

{.emit:["""
  template<typename T, typename Op>
  __global__ void cuda_apply_scal(const int rank,
                                  const int len,
                                  const int *  __restrict__ dst_shape,
                                  const int *  __restrict__ dst_strides,
                                  const int dst_offset,
                                  T * __restrict__ dst_data,
                                  Op f,
                                  const T scalar){

    for (int elemID = blockIdx.x * blockDim.x + threadIdx.x;
         elemID < len;
         elemID += blockDim.x * gridDim.x) {

      // ## we can't instantiate the variable outside the loop
      // ## each threads will store its own in parallel
      const int dst_real_idx = cuda_getIndexOfElementID(
                               rank,
                               dst_shape,
                               dst_strides,
                               dst_offset,
                               elemID);

      f(&dst_data[dst_real_idx], scalar);
    }
  }
"""].}