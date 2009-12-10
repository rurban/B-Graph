# B/Graph.pm
# Copyright (C) 1997 Stephen McCamant. All rights reserved.
# This program is free software; you can redistribute and/or modifiy it
# under the same terms as Perl itself.
package B::Graph;
$VERSION = 0.02;

use 5.004; # Some 5.003_??s might work
use B qw(class main_start main_root main_cv sv_undef svref_2object);
use B::Asmdata qw(@specialsv_name);

my %nodes; # addr => have we printed it?
my @edges; # [from => to, line, type]
my @todo; # nodes to print
my($addrs, $type, $style, $sv_shape, $dump_svs, $dump_stashes);
 
sub ad {
    return $ {$_[0]};
}

sub max {
    my($m) = $_[0];
    my $x;
    for $x (@_) {
	$m = $x if $x > $m;
    }
    return $m;
} 

sub proclaim_node {
    return unless @_;
    if ($type eq "vcg") {
	my(@lines) = ();
	my($title, $shape, $color);
	for my $l (@_) {
	    my(@l) = @$l;
	    if ($l[0] eq "title") {
		$title = $l[1];
	    } elsif ($l[0] eq "color") {
		$color = ('white', 'lightgrey', 'lightblue', 'lightred',
		   'lightgreen', 'lightyellow', 'lightmagenta',
		   'lightcyan', 'lilac', 'yellow', 'green', 'cyan',
		   'khaki')[$l[1]];
	    } elsif ($l[0] eq "shape") {
		$shape = $l[1];
	    } elsif ($l[0] eq "text") {
		push @lines, $l[1];
	    } elsif ($l[0] eq "link") {
		if ($l[2] != 0) {
		    if ($addrs) {
			push @lines, "$l[1]: " . sprintf("%x", $l[2]);
		    } else {
			push @lines, "$l[1]";
		    }
		    push @edges, [$title, $l[2], scalar(@lines), $l[3]];
		}
	    } elsif ($l[0] eq "val") {
		push @lines, "$l[1]: $l[2]" if $l[2];
	    } elsif ($l[0] eq "sval") {
		my($v) = $l[2];
		$v =~ s/([\x00-\x1f\"\x80-\xff])/
		        "\\\\x" . sprintf("%x", $1)/eg;
		push @lines, qq/$l[1]: '$v'/ if $v;
	    } else {
		die "unknown node info type: $l[0] (@_)!\n";
	    }
	}

	print "node: { ";
	print qq'title: "$title" ';
	print qq'color: $color ' if $color;
	print qq'shape: $shape ' if $shape;
	print qq'label: "', join("\n", @lines), '"';
	print "}\n\n";
    } elsif ($type eq "dot") {
	my(@lines) = ();
	my($title, $shape, $color);
	for my $l (@_) {
	    my(@l) = @$l;
	    if ($l[0] eq "title") {
		$title = $l[1];
	    } elsif ($l[0] eq "color") {
		$color = ('black', 'gray50', 'navyblue', 'red',
		   'darkgreen', 'brown', 'magenta4',
		   'blue', 'dodgerblue', 'orange', 'darkgreen', 'blue',
		   'khaki4')[$l[1]];
	    } elsif ($l[0] eq "shape") {
	    } elsif ($l[0] eq "text") {
		push @lines, $l[1];
	    } elsif ($l[0] eq "link") {
		if ($l[2] != 0) {
		    if ($addrs) {
			push @lines, "$l[1]: " . sprintf("%x", $l[2]);
		    } else {
			push @lines, "$l[1]";
		    }
		    push @edges, [$title, $l[2], scalar(@lines), $l[3]];
		}
	    } elsif ($l[0] eq "val") {
		push @lines, "$l[1]: $l[2]" if $l[2];
	    } elsif ($l[0] eq "sval") {
		my($v) = $l[2];
		$v =~ s/([\x00-\x1f\"\x80-\xff<>])/"\\x".sprintf("%x", $1)/eg;
		push @lines, qq/$l[1]: '$v'/ if $v;
	    } else {
		die "unknown node info type: $l[0] (@_)!\n";
	    }
	}
	for my $i (1 .. $#lines) {
	    $lines[$i] = "<p" . ($i + 1) . ">" . $lines[$i];
	}
	print "n$title [";
	print qq'color=$color,' if $color;
	print qq'label="', join("|", @lines), '"';
	print "];\n";
    } elsif ($type eq "text") {
	my(@lines) = ();
#	print "@_\n";
	my($title);
	for my $l (@_) {
	    my(@l) = @$l;
	    if ($l[0] eq "title") {
		$title = $l[1];
	    } elsif ($l[0] eq "text") {
		push @lines, $l[1];
	    } elsif ($l[0] eq "link") {
		push @lines, "$l[1] -> $l[2] ($l[3])";
		push @edges, [$title, $l[2], scalar(@lines), $l[3]];
	    } elsif ($l[0] eq "val") {
		push @lines, "$l[1]: $l[2]" if $l[2];
	    } elsif ($l[0] eq "sval") {
		my($v) = $l[2];
		$v =~ s/([\x00-\x1f\"\x80-\xff])/"\\x" . sprintf("%x", $1)/eg;
		push @lines, qq/$l[1]: "$v"/ if $v;
	    } elsif ($l[0] eq "color" or $l[0] eq "shape") {
	    } else {
		die "unknown node info type: $l[0] (@_)!\n";
	    }
	}
	my($m) = max(map(length $_, @lines));
	my($l);
	for $l (@lines) {
	    $l = "|" . $l . (" " x ($m - length($l))) . "|"; 
	}
	unshift @lines, "-" x ($m + 2);
#	substr($lines[0], ($m + 2 - length $title)/2,
#	       length $title) = $title;
	print join("\n", @lines), "\n", "-" x ($m + 2), "\n\n";
    }
}
    
sub proclaim_edge {
    if ($type eq "vcg") {
	print 'edge: { sourcename: "', $_[0],
	      '" targetname: "', $_[1],
	      '" anchor: ', $_[2] || 1,
	      [[" priority: 5",
		" priority: 0 color: cyan",
		" priority: 0 color: pink",
		" priority: 5 color: lightgrey"],
	       [" priority: 0 color: lightgrey",
		" priority: 0 color: cyan",
		" priority: 10 color: magenta thickness: 8 arrowsize: 20",
		" priority: 0 color: lightgrey"]]->[!$style][$_[3] || 0],    
	      qq'}\n';
    } elsif ($type eq "dot") {
	print 'n', $_[0], ($_[2] ? ':p' . $_[2] : ""),
	      ' -> n', $_[1], " ",
	      [["[weight=5]",
		"[constraint=false,color=cyan]",
		"[constraint=false,color=pink]",
		"[weight=5,color=lightgrey]"],
	       ["[color=lightgrey]",
		"[color=cyan]",
		"[weight=10,color=magenta,style=bold]",
		"[color=lightgrey]"]
	       ]->[!$style][$_[3] || 0], ";\n";
    } elsif ($type eq "text") {
	print "$_[0].$_[2] -> $_[1] ($_[3])\n";
    }
    
}

sub node {
    push @todo, [@_];
}

sub op_flags {
    my($x) = @_;
    my(@v);
    push @v, "V" if ($x & 3) == 1;
    push @v, "S" if ($x & 3) == 2;
    push @v, "L" if ($x & 3) == 3;
    push @v, "K" if $x & 4;
    push @v, "P" if $x & 8;
    push @v, "R" if $x & 16;
    push @v, "M" if $x & 32;
    push @v, "T" if $x & 64;
    push @v, "*" if $x & 128;
    return join("", @v);
}

sub op_common {
    my($op) = @_;
    if ($op->flags & 4 and class($op) ne "OP") { # OPf_KIDS
	my $kid;
	for ($kid = $op->first; $$kid; $kid = $kid->sibling) {
	    node($kid->graph);
	}
    }
    my($n) = $op->ppaddr;
    return (
	    ['title' => $$op],
	    ['color' => {'OP' => 0, 'UNOP' => 1, 'BINOP' => 2,
			 'LOGOP' => 3, 'CONDOP' => 4, 'LISTOP' => 5,
			 'PMOP' => 6, 'COP' => 7, 'SVOP' => 8,
			 'PVOP' => 9, 'GVOP' => 10, 'CVOP' => 11,
			 'LOOP' => 12}->{class($op)} || 0],
	    ['text', join("", $n, " (", class($op), ")")],
	    ($addrs ? ['text', sprintf("%x", $$op)] : ()),
	    ['val', "op_type", $op->type],
	    ['sval', "op_flags", op_flags($op->flags)],
	    ['link', "op_next", ad($op->next), ($n ne "pp_cond_expr") && 2],
	    ['link', "op_sibling", ad($op->sibling), 1],
	    ['val', "op_targ", $op->targ],
	    ['val', "op_seq", $op->seq],
	    ['val', "op_private", $op->private],
	    );
}

sub B::OP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    return op_common($op);
}

sub B::UNOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = op_common($op);
    push @l, ['link', "op_first", ad($op->first), 0];
    if (ad($op->first) and ad($op->first->sibling)) {
	my($kid) = $op->first->sibling;
	while ($$kid) {
	    push @l, ['link', "(stepchild)", $$kid, 3];
	    $kid = $kid->sibling;
	}
    }
    return @l;
}

sub B::BINOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    return (op_common($op),
	    ['link', "op_first", ad($op->first), 0],
	    ['link', "op_last", ad($op->last), 0],
	    );
}

sub B::LOGOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = op_common($op);
    push @l, ['link', "op_first", ad($op->first), 0];
    if (ad($op->first) and ad($op->first->sibling)) {
	my($kid) = $op->first->sibling;
	while ($$kid) {
	    push @l, ['link', "(stepchild)", $$kid, 3];
	    $kid = $kid->sibling;
	}
    }
    my($t) = 0;
    $t = 2 if {'pp_or' => 1, 'pp_and' => 1, 'pp_mapwhile' => 1,
	       'pp_grepwhile' => 1, 'pp_entertry' => 1}->{$op->ppaddr};
    push @l, ['link', "op_other", ad($op->other), $t];
    return @l;
}

sub B::CONDOP::graph {
    my ($op) = @_;    
    return if $nodes{$$op}++;
    return (op_common($op),
	    ['link', "op_first", ad($op->first), 0],
	    ['link', "op_true", ad($op->true), 2],
	    ['link', "op_false", ad($op->false), 2],
	    );
}

sub B::LISTOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = op_common($op);
    push @l, ['link', "op_first", ad($op->first), 0];
    push @l, ['val', "op_children", $op->children];
    if (ad($op->first)) {
	my($kid) = $op->first->sibling;
	while (class($kid) ne "NULL" and ad($kid->sibling)) {
	    push @l, ['link', "(child)", $$kid, 3];
	    $kid = $kid->sibling;
	}
    }
    push @l, ['link', "op_last", ad($op->last), 0];
    return @l;
}

sub B::LOOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = op_common($op);
    push @l, ['link', "op_first", ad($op->first), 0];
    push @l, ['val', "op_children", $op->children];
    if (ad($op->first)) {
	my($kid) = $op->first->sibling;
	while (class($kid) ne "NULL" and ad($kid->sibling)) {
	    push @l, ['link', "(child)", $$kid, 3];
	    $kid = $kid->sibling;
	}
    }
    push @l, (['link', "op_last", ad($op->last), 0],
	      ['link', "op_redoop", ad($op->redoop), 2],
	      ['link', "op_nextop", ad($op->nextop), 2],
	      ['link', "op_lastop", ad($op->lastop), 2],
	      );
    node($op->redoop->graph);
    node($op->nextop->graph);
    node($op->lastop->graph);
    return @l;
}


sub B::PMOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = (op_common($op),
	      ['link', "op_first", ad($op->first), 0],
	      ['link', "op_last", ad($op->last), 0],
	      ['val', "op_children", $op->children],
	      ['link', "op_pmreplroot", ad($op->pmreplroot), 0],
	      ['link', "op_pmreplstart", ad($op->pmreplstart), 2],
	      ['link', "op_pmnext", ad($op->pmnext), 0],
	      ['sval', "op_pmregexp->precomp", $op->precomp],
	      ['link', "op_pmshort", ad($op->pmshort), 0],
	      ['val', "op_pmflags", $op->pmflags],
	      ['val', "op_pmslen", $op->pmslen],
	      );
    node($op->pmshort->graph);
    node($op->pmreplroot->graph);
    return @l;
}

sub B::COP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my ($filegv) = $op->filegv;
    my(@l) = (op_common($op),
	      ['val', "cop_label", $op->label],
	      ['link', "cop_stash", ad($op->stash), 0],
	      ['link', "cop_filegv", $$filegv, 0],
	      ['val', "cop_seq", $op->cop_seq],
	      ['val', "cop_arybase", $op->arybase],
	      ['val', "cop_line", $op->line],
	      );
    node($filegv->graph);
    return @l;
}

sub B::SVOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = (op_common($op),
	      ['link', "op_sv", ad($op->sv), 0],
	      );
    node($op->sv->graph);
    return @l;
}

sub B::PVOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    return (op_common($op),
	    ['sval', 'op_pv', $op->pv],
	    );
}

sub B::GVOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = (op_common($op),
	      ['link', "op_gv", ad($op->gv), 0],
	      );
    node($op->gv->graph);
    return @l;
}

sub B::CVOP::graph {
    my ($op) = @_;
    return if $nodes{$$op}++;
    my(@l) = (op_common($op),
	      ['link', "op_cv", ad($op->cv), 0],
	      );
    node($op->cv->graph);
    return @l;
}

sub sv_flags {
    my($x) = @_;
    my(@v);
    push @v, "Pb" if $x & 0x100;
    push @v, "Pt" if $x & 0x200;
    push @v, "Pm" if $x & 0x400;
    push @v, "T" if $x & 0x800;
    push @v, "O" if $x & 0x1000;
    push @v, "Mg" if $x & 0x2000;
    push @v, "Ms" if $x & 0x4000;
    push @v, "Mr" if $x & 0x8000;
    push @v, "I" if $x & 0x10000;
    push @v, "N" if $x & 0x20000;
    push @v, "P" if $x & 0x40000;
    push @v, "R" if $x & 0x80000;
    push @v, "F" if $x & 0x100000;
    push @v, "L" if $x & 0x200000;
    push @v, "B" if $x & 0x400000;
    push @v, "Ro" if $x & 0x800000;
    push @v, "(i)" if $x & 0x1000000;
    push @v, "(n)" if $x & 0x2000000;
    push @v, "(p)" if $x & 0x4000000;
    push @v, "S" if $x & 0x8000000;
    push @v, "V" if $x & 0x10000000;
    return join("", @v);
}

sub sv_magic {
    my($sv) = @_;
    my(@l) = ();
    foreach my $mg ($sv->MAGIC) {
	push @l, (['text', 'MAGIC'],
		  ['sval', ' TYPE', $mg->TYPE],
		  ['val', ' PRIVATE', $mg->PRIVATE],
		  ['val', ' FLAGS', $mg->FLAGS],
		  ['link', ' OBJ', ad($mg->OBJ)],
		  );
	push @l, ['sval', ' PTR', $mg->PTR] unless $mg->TYPE eq "s";
	node($mg->OBJ->graph);
    }
    return @l;
}

sub sv_common {
    my($sv) = @_;
    my(@l);
    @l = (['shape', $sv_shape],
	  ['title', $$sv],
	  ['color', {'SV' => 0, 'PV' => 1, 'IV' => 2, 'NV' => 3,
		     'RV' => 4, 'PVIV' => 5, 'PVNV' => 6, 'AV' => 7,
		     'HV' => 8, 'GV' => 9, 'CV' => 10, 'BM' => 11,
		     'PVLV' => 12, 'PVMG' => 6, 'IO' => 5}
	   ->{class($sv)} || 0],
	  ['text', class($sv) . ($addrs ? " " . sprintf("%x",$$sv) : "")],
	  ['val', 'REFCNT', $sv->REFCNT],
	  ['sval', 'FLAGS', sv_flags($sv->FLAGS)],	  
	  );
    push @l, sv_magic($sv) if ($sv->FLAGS & 0xff) >= 7;
    return @l;
}

sub B::SV::graph {
    my ($sv) = @_;
    return unless $$sv;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return sv_common($sv);
}

sub B::RV::graph {
    my($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    node($sv->RV->graph);
    return (sv_common($sv),
	    ['link', 'xrv_rv', ad($sv->RV), 0],
	    );
}

sub pv_common {
    my($sv) = @_;
    my(@l) = sv_common($sv);
    my($pv) = $sv->PV;
    unless ($pv eq '') {
	push @l, ['sval', 'xpv_pv', $pv];
	push @l, ['val', 'xpv_cur', length($pv)];
    }
    return @l;
}

sub B::PV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return pv_common($sv);
}

sub B::IV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (sv_common($sv), ['val', 'xiv_iv', $sv->IV]);
}

sub B::NV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (sv_common($sv),
	    ['val', 'xiv_iv', $sv->IV],
	    ['val', 'xnv_nv', $sv->NV],
	    );
}

sub B::PVIV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (pv_common($sv), ['val', 'xiv_iv', $sv->IV]);
}

sub pvnv_common
{
    my($sv) = @_;
    return (pv_common($sv),
	    ['val', 'xiv_iv', $sv->IV],
	    ['val', 'xnv_nv', $sv->NV],
	    );
}

sub B::PVNV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return pvnv_common($sv);
}

sub B::PVLV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (pvnv_common($sv),
	    ['val', 'xlv_targoff', $sv->TARGOFF],
	    ['val', 'xlv_targlen', $sv->TARGLEN],
	    ['sval', 'xlv_type', chr($sv->TYPE)],
	    );
}

sub B::BM::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (pvnv_common($sv),
	    ['val', 'xbm_useful', $sv->USEFUL],
	    ['val', 'xbm_previous', $sv->PREVIOUS],
	    ['sval', 'xbm_rare', chr($sv->RARE)],
	    );
}

sub B::CV::graph {
    my ($sv) = @_;
    return unless $dump_svs;
    my($stash) = $sv->STASH;
    my($start) = $sv->START;
    my($root) = $sv->ROOT;
    my($padlist) = $sv->PADLIST;
    my($gv) = $sv->GV;
    my($filegv) = $sv->FILEGV;
    return if $nodes{$$sv}++;
    node($start->graph) if $start;
    node($root->graph) if $root;
    node($gv->graph) if $gv;
    node($filegv->graph) if $filegv;
    node($padlist->graph) if $padlist;
    node($stash->graph) if $stash and $dump_stashes;
    node($sv->OUTSIDE->graph) if $sv->OUTSIDE;
    return (pvnv_common($sv),
	    ['link', 'STASH', $$stast, 0],
	    ['link', 'START', $$start, 2],
	    ['link', 'ROOT', $$root, 0],
	    ['link', 'GV', $$gv, 0],
	    ['link', 'FILEGV', $$filegv, 0],
	    ['val', 'DEPTH',$sv->DEPTH, 0],
	    ['link', 'PADLIST', $$padlist, 0],
	    ['link', 'OUTSIDE', ad($sv->OUTSIDE), 0],
	    );
}

sub B::AV::graph {
    my ($av) = @_;
    return unless $dump_svs;
    my(@array) = $av->ARRAY;
    return if $nodes{$$av}++;
    my($n) = 0;
    my(@l) = sv_common($av);
    push @l, ['text', 'ARRAY:'];
    foreach (@array) {
	push @l, ['link', $n++, $$_, 0];
    }
    push @l, (['val', 'FILL', scalar(@array)],
	      ['val', 'MAX', $av->MAX],
	      ['val', 'OFF', $av->OFF],
	      ['val', 'AvFLAGS', $av->AvFLAGS]
	      );
    map(node($_->graph), @array);
    return @l;
}

sub B::HV::graph {
    my ($hv) = @_;
    return unless $dump_svs;
    my(@array) = $hv->ARRAY;
    my($k, $v, $n, @values);
    return if $nodes{$$hv}++;
    my(@l) = sv_common($hv);
    push @l, ['text', "ARRAY:"];
    while (@array) {
	($k, $v) = (shift(@array), shift(@array));
	$k = "''" if $k eq '"';
	next if $k =~ /_</ or $k =~ /::/;
	if ($v and ($n++ < 55 or $type ne "vcg")) {
	    push @l, ['link', "$k => ", $$v, 0];
	} else {
	    push @l, ['text', "$k => $$v"];
	}
	push @values, $v;
    }
    push @l, (['val', 'FILL', $hv->FILL],
	      ['val', 'MAX', $hv-MAX],
	      ['val', 'KEYS', $hv->KEYS],
	      ['val', 'RITER', $hv->RITER],
	      ['val', 'NAME', $hv->NAME],
	      ['link', 'PMROOT', ad($hv->PMROOT), 0]
	      );
    node($hv->PMROOT->graph) if $hv->PMROOT;
    map(node($_->graph), @values);
    return @l;
}

    
sub B::GV::graph {
    my ($gv) = @_;
    return unless $dump_svs;
    my ($sv) = $gv->SV;
    my ($av) = $gv->AV;
    my ($cv) = $gv->CV;
    return if $nodes{$$gv}++;
    my(@l) = sv_common($gv);
    my($name) = $gv->NAME;
    $name = "''" if $name eq '"';
    push @l, (['sval', 'NAME', $name],
	      ['link', 'STASH', ad($gv->STASH), 0],
	      ['link', 'SV', $$sv, 0],
	      ['val', 'GvREFCNT', $gv->GvREFCNT],
	      ['link', 'FORM', ad($gv->FORM)],
	      ['link', 'AV', $$av, 0],
	      ['link', 'HV', ad($gv->HV), 0],
	      ['link', 'EGV', ad($gv->EGV), 0],
	      ['link', 'CV', $$cv, 0],
	      ['link', 'IO', ad($gv->IO), 0],
	      ['val', 'CVGEN', $gv->CVGEN],
	      ['val', 'LINE', $gv->LINE],
	      ['link', 'FILEGV', ad($gv->FILEGV), 0],
	      ['val', 'GvFLAGS', $gv->GvFLAGS],
	      );
    node($sv->graph) if $sv;
    node($av->graph) if $av;
    node($cv->graph) if $cv;
    node($gv->HV->graph) if $gv->HV;
    node($gv->IO->graph) if $gv->IO;
    node($gv->STASH->graph) if $gv->STASH and $dump_stashes;
    node($gv->EGV->graph) if $gv->EGV;
    return @l;
}

sub B::IO::graph {
    my $sv = shift;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    my(@l) = sv_common($sv);
    push @l, (['val', 'LINES', $sv->LINES],
	      ['val', 'PAGE', $sv->PAGE],
	      ['val', 'PAGE_LEN', $sv->PAGE_LEN],
	      ['val', 'LINES_LEFT', $sv->LINES_LEFT],
	      ['sval', 'TOP_NAME', $sv->TOP_NAME],
	      ['link', 'TOP_GV', ad($sv->TOP_GV)],
	      ['sval', 'FMT_NAME', $sv->FMT_NAME],
	      ['link', 'FMT_GV', ad($sv->FMT_GV)],
	      ['sval', 'BOTTOM_NAME', $sv->BOTTOM_NAME],
	      ['link', 'BOTTOM_GV', ad($sv->BOTTOM_GV)],
	      ['val', 'SUBPROCESS', $sv->SUBPROCESS],
	      );
    node($sv->TOP_GV->graph) if $sv->TOP_GV;
    node($sv->FMT_GV->graph) if $sv->FMT_GV;
    node($sv->BOTTOM_GV->graph) if $sv->BOTTOM_GV;
    return @l;
}

sub B::SPECIAL::graph {
    my $sv = shift;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    return (['title', $$sv],
	    ['text', $specialsv_name[$$sv]],
	    );
}

sub B::NULL::graph {
    my($sv) = shift;
    return unless $dump_svs;
    return if $nodes{$$sv}++;
    my($t);
    if ($$sv == $ {sv_undef}) {
	$t = "sv_undef";
    } else {
	$t = ($type eq "text" ? "   NULL   " : "NULL");
    }
    return (['title', $$sv],
	    ['text', $t],
	    );
}

sub compile {
    my($arg);
    my(@objs);
    $style = 1;
    $dump_stashes = 0;
    $dump_svs = 1;
    $sv_shape = 'ellipse';
    $addrs = 0;
    $type = 'text';
    for $arg (@_) {
	if (substr($arg, 0, 1) eq "-") {
	    $arg = lc $arg;
	    $arg =~ tr/_-//d;
	    if ($arg eq "stashes") {
		$dump_stashes = 1;
	    } elsif ($arg eq "nostashes") {
		$dump_stashes = 0;
	    } elsif ($arg eq "compileorder") {
		$style = 1;
	    } elsif ($arg eq "runorder") {
		$style = 0;
	    } elsif ($arg eq "svs") {
		$dump_svs = 1;
	    } elsif ($arg eq "nosvs") {
		$dump_svs = 0;
	    } elsif ($arg eq "ellipses") {
		$sv_shape = 'ellipse';
	    } elsif ($arg eq "rhombs") {
		$sv_shape = 'rhomb';
	    } elsif ($arg eq "text") {
		$type = 'text';
	    } elsif ($arg eq "vcg") {
		$type = 'vcg';
	    } elsif ($arg eq "dot") {
		$type = 'dot';
	    } elsif ($arg eq "addrs") {
		$addrs = 1;
	    } elsif ($arg eq "noaddrs") {
		$addrs = 0;
	    }
	} else {
	    push @objs, \*{"main::$arg"};
	}
    }

    if ($type eq "vcg") {
	print "graph: {\n";
	print "layout_downfactor: 10\n";
	print "layout_upfactor:   1\n";
	print "layout_nearfactor: 5\n";
	print "layoutalgorithm: dfs\n\n";
    } elsif ($type eq "dot") {
	$pname = $0;
	$pname = "(cmdline)" if $pname eq "-e";
	print "digraph \"$pname\" {\n";
	print "rankdir=LR;\nnode [shape=record];\nedge [color=black];\n";
    }
    return sub {
	if (@objs) {
	    if ($dump_svs) {
		map(unshift(@todo, [svref_2object($_)->graph]), @objs); 
	    } else {
		foreach my $obj (@objs) {
		    my($cv) = svref_2object(*{*$obj}{CODE});
		    if ($style == 0) {
			node($cv->ROOT->graph);
			unshift @todo, [$cv->START->graph];
		    } else {
			node($cv->START->graph);
			unshift @todo, [$cv->ROOT->graph];
		    }
		}
	    }
	} else {
	    if ($style == 0) {
		node((main_root)->graph);
		unshift @todo, [(main_start)->graph];
	    } else {
		node((main_start)->graph);
		unshift @todo, [(main_root)->graph];
	    }
	    node((main_cv)->graph);
	}
	my($n);
	proclaim_node(@$n) while $n = shift @todo;
	my($e);
	for $e (@edges) {
	    if (exists $nodes{$e->[0]} and exists $nodes{$e->[1]}) {
		proclaim_edge(@$e);
	    }
	    else {
		# print STDERR "$e->[0] =/=> $e->[1]\n";
	    }
	}
	print "}\n" if $type eq "vcg" or $type eq "dot"; 
    }
    
}

1;
__END__

=head1 NAME

B::Graph - Perl compiler backend to produce graphs of OP trees

=head1 SYNOPSIS

  perl -MO=Graph,-text prog.pl >graph.txt

  perl -MO=Graph,-vcg prog.pl >graph.vcg
  xvcg graph.vcg

  perl -MO=Graph,-dot prog.pl | dot -Tps >graph.ps

=head1 DESCRIPTION

This module is a backend to the perl compiler (B::*) which, instead of
outputting bytecode or C based on perl's compiled version of a program,
writes descriptions in graph-description languages specifying graphs that
show the program's structure. It currently generates descriptions for the
VCG tool (C<http://www.cs.uni-sb.de/RW/users/sander/html/gsvcg1.html>) and
Dot (part of the graph visualization toolkit from AT&T:
C<http://www.research.att.com/sw/tools/graphviz/>). It also can produce
plain text output (which is more useful for debugging the module itself than
anything else, though you might be able to make cut the nodes out and make
a mobile or something similar).

=head1 OPTIONS

Like any other compiler backend, this module needs to be invoked using the
C<O> module to run correctly:

  perl -MO=Graph,-opt,-opt,-opt program.pl
  OR
  perl -MO=Graph,-opt,obj -e 'print "Hello, world!\n"'
  OR EVEN
  perl -e 'use O qw(Graph -opt obj obj); print "hi!\n";'

C<Obj> is the name of a perl variable whose contents will be examined.
It can't be a my() variable, and it shouldn't have a prefix symbol
('$@^*'), though you can specify a package -- the name will be used to
look up a GV, whose various fields will lead to the scalar, array, and
other values that correspond to the named variable. If no object is
specified, the whole main program, including the CV that points to its
pad, will be displayed.

Each of the the C<opt>s can come from one of the following (each set is
mutually exclusive; case and underscores are insignificant):

=head2 -text, -vcg, -dot

Produce output of the appropriate type. The default is '-text', which isn't
useful for much of anything (it does draw some nice ASCII boxes, though).

=head2 -addrs, -no_addrs

Each of the nodes on the graph produced corresponds to a C structure that
has an address and includes pointers to other structures. The module uses
these addresses to decide how to draw edges, but it makes the graph more
compact if they aren't printed. The default is '-no_addrs'.

=head2 -compile_order, -run_order

The collection of OPs that perl compiles a script into has two different
layers of structure. It has a tree structure which corresponds roughly
to the synactic nesting of constructs in the source text, and a 
roughly linked-list representation, essentially a postorder traversal
of this tree, which is used at runtime to decide what to do next.
The graph can be drawn to emphasize one structure or the other. The former,
'compile_order', is the default, as it tends to lead to graphs with aspect
ratios close to those of standard paper.

=head2 -SVs, -no_SVs

If OPs represent a program's compiled code, SVs represent its data. This
includes literal numbers and strings (IVs, NVs, PVs, PVIVs, and PVNVs),
regular arrays, hashes, and references (AVs, HVs, and RVs), but also the
structures that correspond to individual variables (special HVs for symbol
tables and GVs to represent values within them, and special AVs that hold
my() variables (as well as compiler temporaries)), structures that keep
track of code (CVs), and a variety of others. The default is to display
all these too, to give a complete picture, but if you aren't in a holistic
mood, you can make them disappear.

=head2 -ellipses, -rhombs

The module tries to give the nodes representing SVs a different shape from
those of OPs. OPs are usually rectangular, so two obvious shapes for SVs
are ellipses and rhombuses (stretched diamonds). This option currently only
makes a difference for VCG (ellipse is the default).

=head2 -stashes, -no_stashes

The hashes that perl uses to represent symbol tables are called 'stashes'.
Since every GV has a pointer back to its stash, it's virtually inevitable
for the links in a graph to lead to the main stash. Unfortunately stashes,
especially the main one, can be quite big, and lead to forests of other
structures -- there's one GV and another SV for each magic variable, plus
all of @INC and %ENV, and so on. To prevent information overload, then,
the display of stashes is disabled by default.

=head1 WHAT DOES THIS ALL MEAN?

=head2 SvFLAGS abbreviations

    Pb     SVs_PADBUSY   reserved for tmp or my already
    Pt     SVs_PADTMP    in use as tmp
    Pm     SVs_PADMY     in use a "my" variable
    T      SVs_TEMP      string is stealable?
    O      SVs_OBJECT    is "blessed"
    Mg     SVs_GMG       has magical get method
    Ms     SVs_SMG       has magical set method
    Mr     SVs_RMG       has random magical methods
    I      SVf_IOK       has valid public integer value
    N      SVf_NOK       has valid public numeric (float) value
    P      SVf_POK       has valid public pointer (string) value
    R      SVf_ROK       has a valid reference pointer
    F      SVf_FAKE      glob or lexical is just a copy
    L      SVf_OOK       has valid offset value (mnemonic: lvalue)
    B      SVf_BREAK     refcnt is artificially low
    Ro     SVf_READONLY  may not be modified
    (i)    SVp_IOK       has valid non-public integer value
    (n)    SVp_NOK       has valid non-public numeric value
    (p)    SVp_POK       has valid non-public pointer value
    S      SVp_SCREAM    has been studied?
    V      SVf_AMAGIC    has magical overloaded methods

=head2 op_flags abbreviations

    V      OPf_WANT_VOID    Want nothing (void context)
    S      OPf_WANT_SCALAR  Want single value (scalar context)
    L      OPf_WANT_LIST    Want list of any length (list context)
    K      OPf_KIDS         There is a firstborn child.
    P      OPf_PARENS       This operator was parenthesized.
                             (Or block needs explicit scope entry.)
    R      OPf_REF          Certified reference.
                             (Return container, not containee).
    M      OPf_MOD          Will modify (lvalue).
    T      OPf_STACKED      Some arg is arriving on the stack.
    *      OPf_SPECIAL      Do something weird for this op (see op.h)        

=head1 AUTHOR

Stephen McCamant <alias@mcs.com>

=head1 SEE ALSO

L<dot(1)>, L<xvcg(1)>, L<perl(1)>, L<perlguts(1)>.

=cut
