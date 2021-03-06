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

# By convention a is the LHS (left-hand side)
# b is the rhs (right-hand side)

import  ../private/sequninit,
        ../tensor/tensor,
        ./ag_data_structure

type AddGate* {.final.} [TT] = ref object of Gate[TT]

proc forward[TT](self: AddGate[TT], a, b: Variable[TT]): Variable[TT] {.inline.}=
  new result

  result.context = a.context
  result.value = a.value + b.value

method backward*[TT](self: AddGate[TT], payload: Payload[TT]): SmallDiffs[TT] {.noInit, inline.}=
  let gradient = payload.variable.grad
  result = newSeq[TT](2)
  result[0] = gradient
  result[1] = gradient

proc `+`*[TT](a, b: Variable[TT]): Variable[TT] =
  when compileOption("boundChecks"):
    check_ctx(a, b)

  # Gate
  var gate: AddGate[TT]
  new gate

  # Node
  var node: Node[TT]
  new node

  node.gate = gate
  node.parents = newSeq[VariablePtr[TT]](2)
  node.parents[0] = a.weakRef
  node.parents[1] = b.weakRef

  a.context.push(node)

  # Resulting var
  result = gate.forward(a, b)
  node.payload = Payload[TT](kind: pkVar, variable: result)

  # Caching for backprop
  if a.is_grad_needed or b.is_grad_needed:
    result.grad = zeros_like result.value
    result.requires_grad = true

type SubGate* {.final.} [TT] = ref object of Gate[TT]

proc forward[TT](self: SubGate[TT], a, b: Variable[TT]): Variable[TT] {.inline.}=
  new result

  result.context = a.context
  result.value = a.value - b.value

method backward*[TT](self: SubGate[TT], payload: Payload[TT]): SmallDiffs[TT] {.noInit, inline.}=
  let gradient = payload.variable.grad
  result = newSeqUninit[TT](2)
  result[0] = gradient
  result[1] = -gradient

proc `-`*[TT](a, b: Variable[TT]): Variable[TT] =
  when compileOption("boundChecks"):
    check_ctx(a, b)

  # Gate
  var gate: SubGate[TT]
  new gate

  # Node
  var node: Node[TT]
  new node

  node.gate = gate
  node.parents = newSeqUninit[VariablePtr[TT]](2)
  node.parents[0] = a.weakRef
  node.parents[1] = b.weakRef

  a.context.push(node)

  # Resulting var
  result = gate.forward(a, b)
  node.payload = Payload[TT](kind: pkVar, variable: result)

  # Caching for backprop
  if a.is_grad_needed or b.is_grad_needed:
    result.grad = zeros_like result.value
    result.requires_grad = true
