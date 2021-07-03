=================
Tutorial: Slicing
=================

Arraymancer supports the following slicing syntax. It allows for
selecting dimension subsets, whole dimension, stepping (one out of 2
rows), reversing dimensions, counting from the end.

.. code:: nim

    import math, arraymancer, future

    const
        x = @[1, 2, 3, 4, 5]
        y = @[1, 2, 3, 4, 5]

    var
        vandermonde: seq[seq[int]]
        row: seq[int]

    vandermonde = newSeq[seq[int]]()

    for i, xx in x:
        row = newSeq[int]()
        vandermonde.add(row)
        for j, yy in y:
            vandermonde[i].add(xx^yy)

    let foo = vandermonde.toTensor()

    echo foo

    # Tensor[int] of shape "[5, 5]" on backend "Cpu"
    # |1       1        1       1        1|
    # |2       4        8      16       32|
    # |3       9       27      81      243|
    # |4      16       64     256     1024|
    # |5      25      125     625     3125|

    echo foo[1..2, 3..4] # slice

    # Tensor[int] of shape "[2, 2]" on backend "Cpu"
    # |16      32|
    # |81     243|

    echo foo[3.._, _] # Span slice

    # Tensor[int] of shape "[2, 5]" on backend "Cpu"
    # |4      16       64     256     1024|
    # |5      25      125     625     3125|

    echo foo[_..^3, _] # Slice until (inclusive, consistent with Nim)

    # Tensor[int] of shape "[3, 5]" on backend "Cpu"
    # |1      1        1       1       1|
    # |2      4        8      16      32|
    # |3      9       27      81     243|

    echo foo[_.._|2, _] # Step

    # Tensor[int] of shape "[3, 5]" on backend "Cpu"
    # |1       1        1       1        1|
    # |3       9       27      81      243|
    # |5      25      125     625     3125|

    echo foo[^1..0|-1, _] # Reverse step

    # Tensor[int] of shape "[5, 5]" on backend "Cpu"
    # |5      25      125     625     3125|
    # |4      16       64     256     1024|
    # |3       9       27      81      243|
    # |2       4        8      16       32|
    # |1       1        1       1        1|

Slice mutations
~~~~~~~~~~~~~~~

Slices can also be mutated with a single value, a nested seq or array, a
tensor or tensor slice.

For certain use cases slice mutations can have less than intuitive
results, because the mutation happens on the same memory the whole
time. See the last mutation shown in the following code block for such
an example and the explanation below.

.. code:: nim

    import math, arraymancer, future

    const
        x = @[1, 2, 3, 4, 5]
        y = @[1, 2, 3, 4, 5]

    var
        vandermonde: seq[seq[int]]
        row: seq[int]

    vandermonde = newSeq[seq[int]]()

    for i, xx in x:
        row = newSeq[int]()
        vandermonde.add(row)
        for j, yy in y:
            vandermonde[i].add(xx^yy)

    var foo = vandermonde.toTensor()

    echo foo

    # Tensor[int] of shape "[5, 5]" on backend "Cpu"
    # |1       1        1       1        1|
    # |2       4        8      16       32|
    # |3       9       27      81      243|
    # |4      16       64     256     1024|
    # |5      25      125     625     3125|

    # Mutation with a single value
    foo[1..2, 3..4] = 999

    echo foo
    # Tensor[int] of shape "[5, 5]" on backend "Cpu"
    # |1       1        1       1       1|
    # |2       4        8     999     999|
    # |3       9       27     999     999|
    # |4      16       64     256    1024|
    # |5      25      125     625    3125|

    # Mutation with nested array or nested seq
    foo[0..1,0..1] = [[111, 222], [333, 444]]

    echo foo
    # Tensor[int] of shape "[5, 5]" on backend "Cpu"
    # |111    222       1       1       1|
    # |333    444       8     999     999|
    # |3        9      27     999     999|
    # |4       16      64     256    1024|
    # |5       25     125     625    3125|

    # Mutation with a tensor or tensor slice.
    foo[^2..^1,2..4] = foo[^1..^2|-1, 4..2|-1]

    echo foo
    # Tensor[system.int] of shape [5, 5]" on backend "Cpu"
    # |111    222       1      1       1|
    # |333    444       8    999     999|
    # |3        9      27    999     999|
    # |4       16    3125    625     125|
    # |5       25     125    625    3125|

The careful reader might have expected a different result for the
final mutation `foo[^2..^1,2..4] = foo[^1..^2|-1, 4..2|-1]`. Namely,
that the bottom right block of the input tensor:

.. code:: nim

    # |64      256     1024|
    # |125     625     3125|

might simply be exchanged row wise and reversed column wise to give
the following result:

.. code:: nim

     # |3125    625     125|
     # |1024    256      64|

However, this result would only be obtained, if slicing mutation used
a temporary copy of the input tensor. To see what happens exactly,
consider the following code. Here `foo` is foo as it was computed
*before* the final mutation in the full code sample from above.

.. code:: nim

     # first let's print the LHS we write to
     echo foo[^2..^1, 2..4]
     # Tensor[system.int] of shape [2, 3]" on backend "Cpu"
     # |64     256     1024|
     # |125    625     3125|

     # now print the RHS we read from
     echo foo[^1..^2|-1, 4..2|-1]
     # Tensor[system.int] of shape [2, 3]" on backend "Cpu"
     # |3125   625     125|
     # |1024   256      64|

     # this means we first perform this:
     foo[^2, 2..4] = foo[^1, 4..2|-1]
     echo foo
     # Tensor[system.int] of shape [5, 5]" on backend "Cpu"
     # |111    222       1      1       1|
     # |333    444       8    999     999|
     # |3        9      27    999     999|
     # |4       16    3125    625     125|
     # |5       25     125    625    3125|

     # and then the following. At this step (compare output
     foo[^1, 2..4] = foo[^2, 4..2|-1]
     echo foo
     # Tensor[system.int] of shape [5, 5]" on backend "Cpu"
     # |111    222       1      1       1|
     # |333    444       8    999     999|
     # |3        9      27    999     999|
     # |4       16    3125    625     125|
     # |5       25     125    625    3125|

In effect it makes it seem like the final mutation does not even do
anything! But that is only, because we are somewhat "inverting" doing
the second to last operation in reverse in the final operation, thus
copying exactly the thing we copied to the second to last row in
reverse back to the last row. But because that is where the values in
the second to last row originated from, nothing "happens".
