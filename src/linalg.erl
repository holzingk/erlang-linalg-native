-module(linalg). 
-vsn('1.0').
-author('simon.klassen').

-import(lists,[reverse/1,append/2,nth/2,seq/2,split/2,zip/2,foldl/3]).

-export([row/2,col/2,cell/3]). 
-export([transpose/1,det/1,inv/1,shape/1]). 
-export([dot/2,inner/2,outer/2,matmul/2,solve/2]). 
-export([zeros/1,ones/1,sequential/1,random/1]).
-export([zeros/2,ones/2,sequential/2,random/2]).
-export([identity/1,diag/1,eye/1,eye/2]).
-export([add/2,sub/2,mul/2,divide/2,pow/2]).
-export([epsilon/1,exp/1,log/1,sqrt/1]).
-export([sum/1,norm/1]).
-export([roots/1,qr/1,svd/1]).

-define(EPSILON,1.0e-12).
-define(NA,na).

-type dim() :: non_neg_integer().
-type scalar() :: number().
-type vector() :: list(scalar()).
-type matrix() :: list(vector()).

% linalg shape 
shape(X) when is_number(X)->
   {};
shape([X|_]=Vector) when is_number(X)->
   {length(Vector)};
shape([[X|_]|_]=Matrix) when is_number(X)->
   NRows = length(Matrix), 
   NCols = length(nth(1,Matrix)), 
   {NRows,NCols}.

% generation (vector)
-spec zeros(dim())->vector().
zeros(0) -> 
    [[]];
zeros(N) -> 
	[ 0.0 ||_<-seq(1,N)].

-spec ones(dim())->vector().
ones(0) -> 
    [[]];
ones(N) -> 
	[ 1.0 ||_<-seq(1,N)].

-spec sequential(dim())->vector().
sequential(0) ->
    [[]];
sequential(N) ->
	[ X||X<-seq(1,N)].

-spec random(dim())->vector().
random(0) ->
    [[]];
random(N) ->
	[ rand:uniform() ||_<-seq(1,N)].

% generation (matrix)
-spec zeros(dim(),dim())->matrix().
zeros(NR,NC) ->
	[ [ 0 || _<-seq(1,NC)] || _<-seq(1,NR)].

-spec ones(dim(),dim())->matrix().
ones(NR,NC) ->
	[ [ 1 || _<-seq(1,NC)] || _<-seq(1,NR)].

-spec sequential(dim(),dim())->matrix().
sequential(NR,NC) ->
	[ [ (((R-1)*NC)+C)/1.0 || C<-seq(1,NC)] || R<-seq(1,NR)].

-spec random(dim(),dim())->matrix().
random(NR,NC) ->
	[ [ rand:uniform() || _<-seq(1,NC)] || _<-seq(1,NR)].

-spec eye(dim())->matrix().
eye(0)->
     eye([[]]);
eye(N)->
     eye(N,N).

-spec eye(dim(),dim())->matrix().
eye(N,M) ->
      [ [ case {R,C} of {C,R} -> 1.0; _->0.0 end||R<-seq(1,M)] || C<-seq(1,N)].

-spec diag(vector()|matrix())->matrix()|vector().
% (V)ector V->M
diag([X|_]=V) when is_number(X)->
	[ [ case R of C -> nth(R,V); _->0.0 end||R<-seq(1,length(V))] || C<-seq(1,length(V))];

% (M)atrix M->V
diag([[X|_]|_]=M) when is_number(X)->
	[ nth(R,nth(R,M))||R<-seq(1,length(M))].

-spec identity(dim())->matrix().
identity(N) ->
	diag(ones(N)).

% Transformation
-spec transpose(matrix())->matrix().
transpose([[]]) -> [];
transpose([[X]]) -> [[X]];
transpose([[] | XXs]) -> transpose(XXs);
transpose([[X | Xs] | XXs]) -> [[X | [H || [H | _Tail ] <- XXs]] | transpose([Xs | [Tail || [_|Tail] <- XXs]])].

% Sum Product
-spec dot(vector(),vector())->scalar().
dot([],[],Sum) ->Sum;
dot([A],[B],Sum) ->Sum+A*B;
dot([A|VecA],[B|VecB],Sum) ->dot(VecA,VecB,Sum+A*B).
dot(VecA,VecB) ->dot(VecA,VecB,0).

% Matrix Multiplication
-spec matmul(matrix(),matrix())->matrix().
matmul(M1 = [H1|_], M2) when length(H1) =:= length(M2) ->
    matmul(M1, transpose(M2), []).

matmul([], _, R) -> lists:reverse(R);
matmul([Row|Rest], M2, R) ->
    matmul(Rest, M2, [outer(Row, M2)|R]).

inner(V1,V2)->
    dot(V1,V2).

outer(V1,V2)->
    outer(V1,V2,[]).
outer(_, [], R) -> lists:reverse(R);
outer(Row, [Col|Rest], R) ->
    outer(Row, Rest, [dot(Row, Col)|R]).

% Note: much slower but succient. 
% matmul_zipwith(M1,M2) -> 
%   [ [ foldl(fun(X,Sum)->Sum+X end,0,lists:zipwith(fun(X,Y)->X*Y end,A,B))|| A <- transpose(M1) ]|| B <- M2 ].


% Arithmetric
exp(M)->
    sig1(M,fun(X)->math:exp(X) end,[]).

log(M)->
    sig1(M,fun(X)->math:log(X) end,[]).

sqrt(M)->
    sig1(M,fun(X)->math:sqrt(X) end,[]).

epsilon(M)->
    sig1(M,fun(X)-> case (abs(X)<?EPSILON) of true->0; false->X end end,[]).

add(M1,M2)->
    sig2(M1,M2,fun(A,B)->A+B end,[]).

sub(M1,M2)->
    sig2(M1,M2,fun(A,B)->A-B end,[]).

mul(M1,M2)->
    sig2(M1,M2,fun(A,B)->A*B end,[]).

divide(M1,M2)->
    sig2(M1,M2,fun(A,B)->case B of 0-> ?NA; B-> A/B end end,[]).

pow(M1,M2)->
    sig2(M1,M2,fun(A,B)->math:pow(A,B) end,[]).

% Reductions
norm(X) when is_number(X)->
    X;
norm([H|_]=Vector) when is_number(H)->
    math:sqrt(sum(pow(Vector,2)));
norm([[H|_]|_]=Matrix) when is_number(H)->
    norm(lists:flatten(Matrix)).

sum([])->0;
sum(X) when is_number(X)->X;
sum([H|_]=Vector) when is_number(H)->
    foldl(fun(A,Sum)->Sum+A end,0,Vector);
sum([H|Tail])->
    sum(H)+sum(Tail).

% Reference
-spec row(dim(),matrix())->vector().
row(I,Matrix) when I>0 ->
    [nth(I,Matrix)];
row(I,Matrix) when I<0 ->
    {A,[_|B]}=split(-(I+1),Matrix),
    append(A,B).

-spec col(dim(),matrix())->vector().
col(J,Matrix) ->
    transpose(row(J,transpose(Matrix))).

-spec cell(dim(),dim(),matrix())->vector().
cell(I,J,Matrix) ->
    nth(J,nth(1,row(I,Matrix))).

% Solves
-spec det(matrix())->scalar().
det([[X]])->
    X;
det([[A,B],[C,D]])->
    A*D-B*C;
det([H|Tail])->
    foldl(fun(A,Sum)->Sum+A end,0,[pow(-1,J-1)*X*det(col(-J,Tail))||{J,X}<-zip(seq(1,length(H)),H)]).

-spec solve(matrix(),matrix())->matrix().
solve(X,B)->
   Inv=inv(X),
   matmul(Inv,B).

-spec inv(matrix())->matrix().
inv([[X]])->
    [[1.0/X]];
inv([[A,B],[C,D]])->
    case det([[A,B],[C,D]]) of
       0.0->err;
       Det->[[D/Det,-1/Det*B],[-1/Det*C,A/Det]]
    end;
inv(M)->
    case det(M) of
       0.0->err;
       Det->divide(transpose(mul(minors(M),cofactors(M))),Det)
    end.

minors(Matrix)->
    {NRows,NCols}=shape(Matrix),
    [[det(col(-J,row(-I,Matrix)))||J<-seq(1,NCols)]||I<-seq(1,NRows)].

cofactors(Matrix)->
    {NRows,NCols}=shape(Matrix),
    [[pow(-1,I)*pow(-1,J)||J<-seq(0,NCols-1)]||I<-seq(0,NRows-1)].

-spec roots(vector()) -> vector().
roots(Vector)->
   linalg_roots:roots(Vector).

-spec qr(matrix()) -> {matrix(),matrix()}.
qr(RowWise)->
   linalg_svd:qr(RowWise).

-spec svd(matrix()) -> {matrix(),matrix(),matrix()}.
svd(RowWise)->
   linalg_svd:svd(RowWise).


% private arithmetic functions

sig1(X,Fun,_) when is_number(X)->
            Fun(X);
sig1([],_Fun,Acc)->
            reverse(Acc);
sig1([H|_]=Vector,Fun,[]) when is_number(H)->
            [Fun(X)||X <-Vector];
sig1([R1|Matrix],Fun,Acc)->
            sig1(Matrix,Fun,[[Fun(X)||X <-R1]|Acc]).


sig2([],[],_Fun,Acc)->
            reverse(Acc);
sig2(X,[],_Fun,Acc) when is_number(X)->
            reverse(Acc);
sig2([],X,_Fun,Acc) when is_number(X)->
            reverse(Acc);
sig2(A,B,Fun,[]) when is_number(A) andalso is_number(B)->
            Fun(A,B);
sig2(A,[B|Vector],Fun,[]) when is_number(A) andalso is_number(B)->
            [Fun(A,X)||X<-[B|Vector]];
sig2([A|Vector],B,Fun,[]) when is_number(A) andalso is_number(B)->
            [Fun(X,B)||X<-[A|Vector]];
sig2([A|VectorA],[B|VectorB],Fun,[]) when is_number(A) andalso is_number(B)->
            [Fun(X,Y)||{X,Y}<-zip([A|VectorA],[B|VectorB])];
sig2(A,[R2|M2],Fun,Acc) when is_number(A)->
            sig2(A,M2,Fun,[[Fun(A,B)||B<-R2]|Acc]);
sig2([R1|M1],B,Fun,Acc) when is_number(B)->
            sig2(M1,B,Fun,[[Fun(A,B)||A<-R1]|Acc]);
sig2([R1|M1],[R2|M2],Fun,Acc)->
            sig2(M1,M2,Fun,[[Fun(A,B)||{A,B}<-zip(R1,R2)]|Acc]).
