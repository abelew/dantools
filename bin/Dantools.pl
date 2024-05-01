#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use File::Basename;
use File::Path qw(make_path);
use File::Spec;
use File::Which;
use lib "$FindBin::Bin/../lib";
use Bio::Dantools;
use autodie;
use Cwd qw"abs_path cwd getcwd";
use Getopt::Long;

#Define which methods can be passed
my @tools = ('pseudogen', 'fragment', 'phylo', 'trasnloc');

#Figure out which method was passed
my $method = $ARGV[0];

if (! defined($method)) {
    die "ERROR: no arguments passed\n";
} elsif (! grep(/^$method$/, @tools)) {
    die "ERROR: Could not find method \"$method\"\n";
};


#Now I need to figure out given the method what I need to run

#This is the whole pseudogenome worker
if ($method eq 'pseudogen') {
    #The first thing I need to do is check to make sure all of my
    #required binaries like hisat2 are loaded
    my @needed = ('hisat2', 'hisat2-build', 'samtools', 'bcftools', 'freebayes-parallel', 'stretcher');
    for my $bin (@needed) {
        die "Need binary ${bin}, not in PATH\n" unless(which("$bin"));
    };

    my $gff = '';
    my $base; #The genome I'll be aligning against
    my $base_fai = ''; #.fai indexes for my reference, not required
    my $base_idx = ''; #.ht2 reference indexes, not required
    my $source = ''; #The input genome
    my $readsu = ''; #input unpaired reads
    my $reads1 = ''; #mate 1 input reads
    my $reads2 = ''; #mate 2 input reads
    my $input_type;
    my $fragment = 'yes';
    my $lengths = '50,200,1000';
    my $min_length = 20;
    my $overlap = 80;
    my $min_variants = 100; #The threshold of variant # to repeat an iteration
    my $output_name = '';
    my $keepers = 'all';
    my $logfile = 'data.tsv';
    my $outdir = '';
    my $threads = 1;
    my $bin_size = 10000;
    my $add_flanks = 'no'; #Whether to add regions to ends of features
    my $flank_lengths = 0,0; #How long to make flanks
    my $feature_type = 'gene';
    my $feature_name = 'ID'; #Which element of gff attributes to select as the "name"
    my $var_fraction = 0.501;
    GetOptions(
        "gff|f=s" => \$gff,
        "base|b=s" => \$base,
        "fai=s" => \$base_fai,
        "base-idx=s" => \$base_idx,
        "source|s=s" => \$source,
        "reads-u=s" => \$readsu,
        "reads-1=s" => \$reads1,
        "reads-2=s" => \$reads2,
        "lengths|l=s" => \$lengths,
        "min-length=s" => \$min_length,
        "overlap=f" => \$overlap,
        "min-var=i" => \$min_variants,
        "output-name=s" => \$output_name,
        "keep|k=s" => \$keepers,
        "logfile=s" => \$logfile,
        "outdir=s" => \$outdir,
        "threads|t=i" => \$threads,
        "bin-size=i" => \$bin_size,
        "add-flanks=s" => \$add_flanks,
        "flank-lengths=s" => \$flank_lengths,
        "feature-type=s" => \$feature_type,
        "var-fraction=f" => \$var_fraction,
        "feature-name=s" => \$feature_name
        ) or die "Error in Parsing Arguments";

    #Checking input arguments and setting them manually for some
    if ("$outdir" eq '') {
        $outdir = getcwd;
    } elsif ( ! -d "$outdir" ) {
        make_path("$outdir");
    }

    if ("$gff" eq '') {
        print "WARNING: no GFF file passed to dantools pseudogen\n";
    }
    $base = File::Spec->rel2abs($base);

    if (! grep /^$keepers/, ('all', 'variants', 'alignments', 'genomes', 'none')) {
        die "ERROR: The keepers argument \"$keepers\" is not supported, supported arguments:\nall, variants, alignments, genomes, none\n"
    }
    if (! -e "$base") {
        die "ERROR: input base file does not exist\n";
    }
    $base = File::Spec->rel2abs($base);

    $lengths =~ tr/ //ds;
    $flank_lengths =~ tr/ //ds;
    my @tmp = split(/\,/, "$flank_lengths");
    if (scalar(@tmp) == 1) {
        $flank_lengths = "$tmp[0],$tmp[0]";
    } elsif (scalar(@tmp) > 2) {
        die "Only two flank lengths are supported, e.g. 200,200";
    }

    #Figure out what "source_type" was brought in, which should make
    #downstream tools not always have to check this:
    if ("$source" ne '') {
        die "Error reading input source file $source" if (! -e "$source");
        $input_type = 'fasta';
        $source = File::Spec->rel2abs($source);
    } elsif ("$readsu" ne '') {
        die "Error reading input reads $readsu" if (! -e "$readsu");
        $input_type = 'fastq_u'; #unpaired fastq
        $readsu = File::Spec->rel2abs($readsu);
    } elsif (("$reads1" ne '') & ("$reads2" ne '')) {
        die "Error reading input reads $reads1" if (! -e "$reads1");
        die "Error reading input reads $reads2" if (! -e "$reads2");
        $input_type = 'fastq_p'; #paired fastq
        $reads1 = File::Spec->rel2abs($reads1);
        $reads2 = File::Spec->rel2abs($reads2);
    }

    if ("$output_name" eq '') {
        $output_name = basename($source, ('.fasta')) . "_on_" . basename($base, ('.fasta'));
    }

    Bio::Dantools::pseudogen(gff => "$gff",
                             base => "$base",
                             fai => "$base_fai",
                             base_idx => "$base_idx",
                             source => "$source",
                             readsu => "$readsu",
                             reads1 => "$reads1",
                             reads2 => "$reads2",
                             input_type => "$input_type",
                             fragment => "$fragment",
                             lengths => "$lengths",
                             min_length => "$min_length",
                             overlap => "$overlap",
                             min_variants => "$min_variants",
                             keepers => "$keepers",
                             output_name => "$output_name",
                             logfile => "$logfile",
                             outdir => "$outdir",
                             threads => "$threads",
                             bin_size => "$bin_size",
                             add_flanks => "$add_flanks",
                             flank_lengths => "$flank_lengths",
                             feature_type => "$feature_type",
                             feature_name => "$feature_name",
                             var_fraction => "$var_fraction"
        );
}