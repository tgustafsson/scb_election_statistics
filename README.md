# scb_election_statistics

A solution to fetching data from SCB's REST service and printing some 
results. The solution is implemented in several programming languages. 

## Task

Read the voting participation for each city in Sweden and print out
the cities with the largest percentage for each election.

## Solution

My initial solution is the `python/lw.py` solution, which centers around 
the Model View Control pattern. This solution tries to use easy to 
understand programming techniques to foster maintainable code. 

However, I started wondering, what is the shortest amount of code that is 
needed to solve the problem. I thought that a functional approach would 
lessen the amount of code needed.
 
### Clojure 

I did the first functional solution in clojure as a learning experience. I 
have read about lisp languages, but never implemented any real code. 
Clojure is nice, and leiningen makes it very easy to get started, and not 
needing to bother about dependencies to 3rd party libraries.
 
The solution is quite short and lands on about 50 lines of code, including 
white lines. It uses higher-order functions quite a bit, like, `filter`, 
`map`, and `zip`.
 
### perl
 
The next implementation was done in perl. I used the exact same solution 
as in the clojure implementation, but tried to finding corresponding perl 
functions. It is possible to program in a functional style in perl, so the 
solution is a one to one mapping to the clojure solution, but the amount 
of code is reduced even further, The solution lands on 36 lines!
 
### java
 
Now, I was up to speed and thought it would be interesting to see if the 
functional style solution could be implemented in java. This would also be 
a learning experience, because I haven't used java in a decade. In turns 
out that java now has support for something denoted `stream`s, which gives 
functions similar to `filter` and `map`.
 
However, reading json in java requires, at least what I could find, that 
the data structures being mapped to real java data types. This has the 
down side that the amount of code increases, but the code becomes more 
type safe and possibly more readable in the end.
 
The java implementation lands on 258 lines. Around five times longer than 
the perl solution. However, the main logic is almost as short as in the 
other languages, thanks to stream in java 1.8.
 
### OCaml
 
The next choice of language was OCaml which is a functionally oriented 
type-safe language. The solution was 105 lines. Some utility functions was 
needed for reading data from the REST API. The main logic lands in in 55 
lines. This is quite a bit compared to perl, clojure, and even java. The 
library I choose for json handling, `Yojson`, was a bit hard to work with, 
and I think this added to the lines of code. I consider the OCaml code 
hard to read and understand than the other solutions, but this may be a 
result of my relative unexperience with the language. 
  
### rust
 
I also started to measure the execution time, more about that later, and 
then I thought that I wanted a solution in a language that gives a native 
executable. OCaml gives a native executable if compiled with the 
`ocamlopt` compiler, and the execution time is very fast. As a learning 
experience, I choose now to implement the solution in rust. I haven't 
touched rust in a while, but have written one program in i before. 
 
Json handling is quite intuitive, but also centers around that the json 
data structure is represented as rust types. Some lines of code are needed 
for this, otherwise the solution is equally short as clojure and java. 

I had to fight the borrow checker a bit before I got a compilable 
implementation. Perl is perl when it comes to strange special symbols, but 
rust is not far away. If the borrow checker complains, try `&`, `*`, or 
`ref`, and hope it works. This is ofcourse also a result of my 
inexperience with the language. 

## Project helpers

Modern languages are associated with at least one "project helper". For 
clojure it is _leiningen_, for OCaml it is _ocamlfind_, for java it is 
_maven_, for rust it is _cargo_. For python and perl, I didn't need one, 
because the dependencies were already part of the installation I used.
 
Both leiningen and cargo are very easy to work with. Maven not so much, 
but I'm glad it was there anyway, because I'm not very used to java 
development so it handled giving me one jar file with all dependencies.
 
I would say that leiningen and cargo make clojure and rust as easy as 
scripting languages to work with. Clojure and OCaml, both have repls to 
work with, which is sometimes very handy.
 
OCaml has _opam_ to easily install libraries, and _ocamlfind_ for building 
and linking your program. I think the concept of leiningen and cargo are 
easier to work with than the combination of _opam_ and _ocamlfind_. 

## Execution time

Worst is ofcourse clojure, if the program is executed via leiningen. The 
execution time is more than 5 seconds.
 
The execution time of the java program, if going directly against the 
produced jar file, is 1.1 seconds. 
 
The execution time of the perl program is 0.55 seconds.
 
The execution time of the OCaml program is 0.45 seconds.

The execution time of the Python program is 0.6 seconds.

The execution time of the rust program is 0.43 seconds.

What we can see from the above is that the programs seems to be I/O bound, 
which is not very strange since the program is doing two requests to a 
REST API. However, whether the program is native binary or executed via an 
interpreter, like perl or python, seems to give some small effect. The 
largest effect on execution time is if the jvm is involved or not.
 
## Conclusions
 
As a learning experince, this was real fun! It was possible to write a 
very short solution, and it centered around higher order functions like 
`filter` and `map`. The shortest, and to some extent also the most 
readable implementation, is the perl one. The most interesting solution is 
the original one, but it uses a completely different approach, but I think 
that approach is more maintainable. 
