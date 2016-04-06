﻿type VertexId = int
type Message = bool
type Color = int
type Weight = real

class PregelGraphColoring
{
	var numVertices: int;
	var vAttr : array<VertexId>;
	var vMsg : array<Message>;
	var msg : array2<Message>;
	var graph: array2<Weight>;
	var sent : array2<bool>;

	/**************************************
	 * Beginning of user-supplied functions
	 **************************************/

	method SendMessage(src: VertexId, dst: VertexId, w: Weight)
		requires valid1(vAttr) && valid2(sent) && valid2(msg)
		requires valid0(src) && valid0(dst)
		modifies msg, sent
		ensures sent[src, dst] ==> vAttr[src] == vAttr[dst];
		ensures !sent[src, dst] ==> vAttr[src] != vAttr[dst];
	{
		if vAttr[src] == vAttr[dst] {
			sent[src,dst] := true;
			sent[dst,src] := true;
			msg[src,dst] := true;
			msg[dst,src] := true;
		} else {
			sent[src,dst] := false;
			sent[dst,src] := false;
		}
	}

	function method MergeMessage(a: Message, b: Message): bool { a || b }

	method VertexProgram(vid: VertexId, state: Color, msg: Message) returns (newState: Color)
		requires valid0(vid) && valid1(vAttr)
		modifies vAttr
	{
		if msg == true {
			// choose a different color nondeterministically
			var color :| color >= 0 && color < vAttr.Length;
			newState := color;
		} else {
			newState := state;
		}
	}

	/************************
	 * Correctness assertions
	 ************************/

	function method correctlyColored(): bool
		requires valid1(vAttr) && valid2(graph) && valid2(sent)
		reads vAttr, this`graph, this`vAttr, this`sent, this`numVertices
	{
		// adjacent vertices have different colors
		forall i,j :: 0 <= i < numVertices && 0 <= j < numVertices ==>
			adjacent(i, j) ==> vAttr[i] != vAttr[j]
	}

	/*******************************
	 * Correctness helper assertions
	 *******************************/

	method Validated(maxNumIterations: nat) returns (res: bool)
		requires numVertices > 1 && maxNumIterations > 0
		requires valid1(vAttr) && valid2(graph) && valid2(sent) && valid2(msg)
		modifies this`numVertices, vAttr, msg, sent
		//ensures res
	{
		var numIterations := pregel(maxNumIterations);
		res := numIterations <= maxNumIterations ==> correctlyColored();
	}

	function method noCollisions(): bool
		requires valid1(vAttr) && valid2(graph) && valid2(sent)
		reads vAttr, this`graph, this`vAttr, this`sent, this`numVertices
	{
		forall vid :: 0 <= vid < numVertices ==> noCollisionAt(vid)
	}

	function method noCollisionAt(src: VertexId): bool
		requires valid0(src) && valid1(vAttr) && valid2(graph) && valid2(sent)
		reads this`graph, this`sent, this`vAttr, this`numVertices, vAttr
	{
		forall dst :: 0 <= dst < numVertices ==> noCollisionBetween(src, dst)
	}

	function method noCollisionBetween(src: VertexId, dst: VertexId): bool
		requires valid0(src) && valid0(dst) && valid1(vAttr) && valid2(graph) && valid2(sent)
		reads this`graph, this`sent, this`vAttr, this`numVertices, vAttr
	{
		adjacent(src, dst) && !sent[src, dst] ==> vAttr[src] != vAttr[dst]
	}

	function method noCollisions'(srcBound: VertexId, dstBound: VertexId): bool
		requires srcBound <= numVertices && dstBound <= numVertices
		requires valid1(vAttr) && valid2(graph) && valid2(sent)
		reads vAttr, this`graph, this`vAttr, this`sent, this`numVertices
	{
		forall src,dst :: 0 <= src < srcBound && 0 <= dst < dstBound ==>
			(adjacent(src, dst) && !sent[src, dst] ==> vAttr[src] != vAttr[dst])
	}

	lemma noCollisionsLemma()
		requires valid1(vAttr) && valid2(graph) && valid2(sent)
		ensures noCollisions'(numVertices, numVertices)
	{
		assume noCollisions();

		var src := 0;
		while src < numVertices
			invariant src <= numVertices
			invariant noCollisions'(src, numVertices)
		{
			var dst := 0;
			assert noCollisionAt(src);
			while dst < numVertices
				invariant dst <= numVertices
				invariant noCollisions'(src, dst)
				invariant forall vid :: 0 <= vid < dst ==>
					(adjacent(src, vid) && !sent[src, vid] ==> vAttr[src] != vAttr[vid])
			{
				assert noCollisionBetween(src, dst);
				assert adjacent(src, dst) && !sent[src, dst] ==> vAttr[src] != vAttr[dst];
				dst := dst + 1;
			}
			src := src + 1;
		}
	}

	/******************
	 * Helper functions
	 ******************/

	function method active(): bool
		requires valid2(sent)
		reads this`sent, this`numVertices
	{
		exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]
	}

	function method adjacent(src: VertexId, dst: VertexId): bool
		requires valid2(graph) && valid0(src) && valid0(dst)
		reads this`graph, this`numVertices
	{
		graph[src,dst] != 0.0
	}

	predicate valid0(vid: int)
		reads this`numVertices
	{
		0 <= vid < numVertices
	}

	predicate valid1<T> (arr: array<T>)
		reads this`numVertices
	{
		arr != null && arr.Length == numVertices
	}

	predicate valid2<T> (mat: array2<T>)
		reads this`numVertices
	{
		mat != null && mat.Length0 == numVertices && mat.Length1 == numVertices
	}

	method pregel(maxNumIterations: nat) returns (numIterations: nat)
		requires numVertices > 1 && maxNumIterations > 0
		requires valid1(vAttr) && valid2(graph) && valid2(sent) && valid2(msg)
		modifies vAttr, msg, sent
		ensures numIterations <= maxNumIterations ==> correctlyColored()
	{
		var vid := 0;
		while vid < numVertices
		{
			vAttr[vid] := VertexProgram(vid, vAttr[vid], false);
			vid := vid + 1;
		}
		sent[0,0] := true;
		numIterations := 0;

		witness_for_existence();
		assert active();

		while (exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]) && numIterations <= maxNumIterations
			//invariant !(exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]) ==> noCollisions()
		{
			forall i,j | 0 <= i < numVertices && 0 <= j < numVertices
			{
				sent[i,j] := false;
			}
			var src := 0;
			// invoke SendMessage on each edage
			while src < numVertices
				invariant src <= numVertices
				invariant forall vid :: 0 <= vid < src ==> noCollisionAt(vid)
				invariant numIterations > maxNumIterations ==> noCollisions()
			{
				var dst := 0;
				while dst < numVertices
					invariant dst <= numVertices
					invariant forall vid :: 0 <= vid < dst ==> noCollisionBetween(src, vid);
					invariant forall vid :: 0 <= vid < src ==> noCollisionAt(vid)
				{
					if adjacent(src, dst)
					{
						SendMessage(src, dst, graph[src,dst]);
					}
					assert noCollisionBetween(src, dst);
					dst := dst + 1;
				}
				assert noCollisionAt(src);
				src := src + 1;
			}
			assert noCollisions();
			//assert exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]; // WRONGLY VERIFIED
			//assert inv();
			if exists i,j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]
			{
				var dstCounter := 0;
				var dstIndices := Permutation(numVertices);
				while dstCounter < numVertices
					invariant isPermutationOf(dstIndices, numVertices)
					
				{
					var dst := dstIndices[dstCounter];
					// Did some vertex send a message to dst?
					if exists src :: 0 <= src < numVertices && sent[src,dst]
					{
						var activated := false;
						var message: Message;
						var srcCounter := 0;
						var srcIndices := Permutation(numVertices);
						// aggregate the messages sent to dst
						while srcCounter < numVertices
						{
							var src := srcIndices[srcCounter];
							if sent[src,dst]
							{
								if !activated
								{
									// keep the first message as is
									message := msg[src,dst];
									activated := true;
								} else {
									// merge the new message with the old one
									message := MergeMessage(message, msg[src,dst]);
								}
							}
							srcCounter := srcCounter + 1;
						}
						// update vertex state according to the result of merges
						vAttr[dst] := VertexProgram(dst, vAttr[dst], message);
					}
					dstCounter := dstCounter + 1;
				}
			}
			numIterations := numIterations + 1;
		}
		noCollisionsLemma();
		//assert numIterations <= maxNumIterations ==> !(exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]);
		//assert numIterations <= maxNumIterations ==> !active();
		//assert numIterations <= maxNumIterations ==> noCollisions();
		//assert !(exists i, j :: 0 <= i < numVertices && 0 <= j < numVertices && sent[i,j]) && noCollisions() ==> correctlyColored();
		//assert !active() && noCollisions() ==> correctlyColored();
		assert numIterations <= maxNumIterations ==> correctlyColored();
	}

	lemma witness_for_existence()
		requires valid2(sent) && numVertices > 0 && sent[0,0]
		ensures active()
	{}

	/**
	 * Given n >= 0, generate a permuation of {0,...,n-1} nondeterministically.
	 */
	method Permutation(n: int) returns (perm: array<int>)
		requires n >= 0
		ensures perm != null
		ensures perm.Length == n
		ensures fresh(perm)
		ensures isPermutationOf(perm, n)
	{
		var all := set x | 0 <= x < n;
		var used := {};
		perm := new int[n];
		CardinalityLemma(n, all);
		while used < all
			invariant used <= all
			invariant |used| <= |all|
			invariant forall i :: 0 <= i < |used| ==> perm[i] in used
			invariant distinct'(perm, |used|)
			decreases |all| - |used|
		{
			CardinalityOrderingLemma(used, all);
			var dst :| dst in all && dst !in used;
			perm[|used|] := dst;
			used := used + {dst};
		}
		assert used == all;
		print perm;
	}

	predicate isPermutationOf(a: array<int>, n: int)
		requires a != null
		reads a
	{
		distinct(a) && forall i :: 0 <= i < a.Length ==> 0 <= a[i] < n
	}

	predicate distinct(a: array<int>)
		requires a != null
		reads a
	{
		distinct'(a, a.Length)
	}

	predicate distinct'(a: array<int>, n: int)
		requires a != null
		requires a.Length >= n 
		reads a
	{
		forall i,j :: 0 <= i < n && 0 <= j < n && i != j ==> a[i] != a[j]
	}

	lemma CardinalityLemma (size: int, s: set<int>) 
		requires size >= 0
		requires s == set x | 0 <= x < size
		ensures	size == |s|
	{
		if(size == 0) {
			assert size == |(set x | 0 <= x < size)|;
		} else {
			CardinalityLemma(size - 1, s - {size - 1});
		}
	}

	lemma CardinalityOrderingLemma<T> (s1: set<T>, s2: set<T>)
		requires s1 < s2
		ensures |s1| < |s2|
	{
		var e :| e in s2 - s1;
		if (s1 == s2 - {e}) {
			assert |s1| == |s2| - 1;
		} else {
			CardinalityOrderingLemma(s1, s2 - {e});
		}
	}
}