#!/usr/bin/perl 

################################################################################

#no locale;
use Getopt::Long;
use Pod::Usage;

use locale;
use POSIX qw(locale_h);
setlocale(LC_CTYPE,"ISO-8859-1");

#param�tres d'initialisation
$htmlparse=0;
$nargs=$#ARGV+1;
$printunk=0;
$skipunk=0; 
$wordseparator=" ";
$characterseparator="";
$verbose=0;
$nlines=0;
$nnlines=0;
$textonly=0;
$vocabulary_output=0;
$normalize=2;
$stmparse=0;
$convertnum=1;
$inputencoding="";
$outputencoding="";
$defaultencoding="ISO-8859-1";
$output="-";
$scriptflag=0;
$ocmd="";
$inittime=time();
$dictionnaryseparator='\s*=>\s*';
$firsttime=1;
$normalize_when="before"; # means normalisation before usage of dictionnary


#lecture des arguments

ARGUMENT : 
#r�cup�ration des options
    GetOptions( 'dictionary|d=s'         => \$dico,
		'inputencoding|ie=s'     => \$inputencoding,
		'outputencoding|oe=s'    => \$outputencoding,
		'printunknown|u:i'       => \$printunknown,
		'skipunknown|s'          => \$spkipunk,
		'inputformat|if=s'       => \$inputformat,
		'verbose|v'              => \$verbose,
		'outputformat|of=s'      => \$outputformat,
		'input|i=s'              => \$input,
		'output|o=s'             => \$output,
		'normalize|n:i'          => \$normalize,
		'normalize_order|no=s'     => \$normalize_when,
		'numtolitterals|l:i'       => \$convertnum,
		'wordseparator|w=s'      => \$wordseparator, 
		'characterseparator|c=s' => \$characterseparator,
		'dictionnaryseparator|ds=s'=> \$dictionnaryseparator,
		'postprocess|p=s'        => \$postprocess,
		'batch|b=s'              => \$batchfile,
		'help'                   => \$help,
		'man'                    => \$man
		) or exit(1);

#if ($normalize==0) { $normalize=2;}
#if ($normalize==-1) {$normalize=0;}



pod2usage(0) if $help;

pod2usage(1) if $man;


#r�cup�ration des noms de fichiers
$nargs=$#ARGV+1;

   for ($j=0;$j<$nargs;$j++) {
	$arg=@ARGV[$j];
	$files[$nfiles]=$arg;
	$nfiles++;
    }

    if ($nfiles==0) {
	$nfiles=1;
	$files[0]="-";
    }

#traitement des options de format et d'encodage

$mask{txt}=$mask{text}=$mask{texte}=$mask{t}=1;
$mask{lex}=128;
$mask{xml}=$mask{x}=2;
$mask{html}=$mask{htm}=6;
$mask{ne}=64;
$mask{stm}=8;
$mask{"stm-ne"}=$mask{ne}|$mask{stm};
$mask{ctm}=16;
$mask{"ctm-ne"}=$mask{ne}|$mask{ctm};
$mask{vocab}=$mask{v}=$mask{voc}=32;

$fields{stm}="";
$fields{ctm}="";

$force_mask=0;
$output_mask=0;

if ($postprocess ne "") {
    $ocmd = "| $postprocess ";
}

if ($inputformat ne "") {
    $force_mask=$mask{"$inputformat"};
}

if ($outputformat ne "") {
    $output_mask=$mask{"$outputformat"};
}

# gestion de l'encodage (v�rifications basique);

if ($inputencoding ne ""  && $inputencoding ne $outputencoding)  {
    &encodingtest($inputencoding) || die "Unknown input encoding : $inputencoding\n";
}

if ($outputencoding ne ""  && $inputencoding ne $outputencoding) {
    &encodingtest($outputencoding) || die "Unknown output encoding : $outputencoding\n";
}

#lecture du dictionnaire si pr�sent

if ($dico ne "") {
    open( DICO, $dico ) || die "error while opening the dictionary file : $dico\n";
    if ($verbose) {
	print STDERR "$utilisation du dictionnaire $dico\n";
    }
    $nwords=0;
    $var{format}='.*';
    $translation_id=0;
  DICOLINE:
    while (<DICO>) {
	chomp;
	if (/^\#\s*declare\s+(\S+)=(\S+)/) {
	    $var{$1}=$2;
	}
	s/^\#.*//;
	s/^\s*//;
	s/\s*$//;
	next DICOLINE if ($_ eq "");
	if ($inputformat=~/$var{format}/) {
	    $nwords++;
	    if (/$dictionnaryseparator/) {
		($word,$translation)=split(/$dictionnaryseparator/,$_,2);
		&addtodic($word,$translation);
	    }
	    else { die "Dictionnary syntax error in $dico at line $.\n";}
	}
    }
    close(DICO);
#    if ($verbose) {
#	foreach $word (keys %partial) {
#	    print STDERR "$word : ".join(",",@{$partial{$word}})."\n";
#	}
#    }
    if ($verbose) { print STDERR "$nwords words in dictionnary\n";}
}

if ($batchfile ne "") {
    open( BATCH, $batchfile ) || die "error while opening the batch : $batchfile\n";
    $nfiles=0;
    
    
  BATCHLINE:
    while (<BATCH>) {
	chop;
	s/^\#.*//;
	s/^\s*//;
	s/\s*$//;
	next BATCHLINE if ($_ eq "");
	if (/^\s*(\S+)/) {
	    $files[$nfiles]=$1;
	    $nfiles++;
	}
	if (/^\s*(\S+)\s+(\S+)/) {
	    $ifile=$1;
	    $ofile=$2;
	    $ofilename{$ifile}=$ofile;
	}

    }
    close(BATCH);
    
    if ($verbose) { print STDERR "$nfiles in batchfile\n";}
}


#d�but du programme

if ($verbose) {
    print STDERR "$nfiles file(s) to process\n";
}

if ($force_mask && $normalize) {&formatinit()}
if (!($output=~/%s/)) { # cas d'un fichier unique de sortie : nettoyage de ce fichier
    open (OFILE, ">$output");
    print OFILE "";
    close OFILE;
}

while($nfile<$nfiles) {
#traitement des fichiers
$file=$files[$nfile];



if ($input ne "") {
    $tmp=$file;
    if ($output=~/\//) {
	$tmp =~ s/.*\///;
    }
    if ($input=~/\.[^\/]$/) {
	$tmp =~ s/\.[^\.]*$//;
    }
    $file=$input;
    $file=~s/\%s/$tmp/g;
}
$msg="reading from $file";
$msg=~s/ \-$/ input/;

if ($output ne "") {
    $tmp="";
    if ($batchfile ne "") {
	$tmp=$ofilename{$file};
	if ($tmp eq "") {
	    $ifile=$file;
	    $ifile=~s/.*\///;
	    $tmp=$ofilename{$ifile};
	    if ($tmp eq "") {
		$ifile =~ s/\.[^\.]*$//;
		$tmp=$ofilename{$ifile};
	    }
	}
    }
    if ($tmp eq "") {
	$tmp=$file;
    }
    if ($output=~/\//) {
	$tmp =~ s/.*\///;
    }
    if ($output=~/\.[^\/]*$/) {
	$tmp =~ s/\.[^\.]*$//;
    }
    $ofile=$output;
    $ofile=~s/\%s/$tmp/g;
    $msg.=" and writing to $ofile";
    $msg=~s/ \-$/ output/;
} else {
    $ofile="-";
    };
if ($verbose) {print STDERR "$msg\n";}


$nfile++;

open(FILE, "<$file") || die "$file:$!";
if (($ocmd ne "") && ($ofile eq "-")) {
  open(OFILE, "$ocmd") || die $!; # ouverture du fichier de sortie
} else {
    if ($output =~ /%s/) {
	open(OFILE, "$ocmd>$ofile") || die $!; # ouverture du fichier de sortie
    } else {
	open(OFILE, "$ocmd>>$ofile") || die $!; # ouverture du fichier unique de sortie en mode append
    }
}


$nline=1;
%unkdic={};
%count={};

$format_mask=$force_mask; # format de fichier par d�faut
while (<FILE>) {
    if (!$format_mask) { # tente de d�terminer le format de fichier d'entr�e si aucun n'est sp�cifi�
	if (/<\?xml.*\?>/i) {$format_mask=$mask{xml};  }
	if (/<html\s*>/i)  {$format_mask=$mask{html}; &addtodic("&nbsp;"," ");}
	if (/^;;/) { $format_mask=$mask{stm}}
	if ($normalize) {&formatinit()}
    }


    # gestion de l'encodage 
    # dans le cas d'un fichier xml, tente de r�cup�rer le format indiqu� dans le header du xml 
    # si aucun n'est sp�cifi� dans les options
    if ($mask{xml} & $format_mask) {
	$/='>';
	if ($inputencoding eq "") {
	    $xmlquote=$_;
	    $xmlquote =~ /<\?xml.*\?>?/i  || ($mask{htm}&$format_mask) || die "XML header missing $xmlquote\n"; 
	    if ($xmlquote =~ /encoding=\"([^\"]+)\"/) {
		$inputencoding=$1; 
		s/encoding=\"([^\"]+)\"/encoding=\"$outputencoding\"/;
	    }
	    else {
		if ($xmlquote =~ /encoding=(\S+)/) {
		    $inputencoding=$1;
		}
		else { $inputencoding=$defaultencoding;
		   }
	    }
	}
	if ($outputencoding eq "") {
	    $outputencoding=$inputencoding;
	}
    }
	
    if ($inputencoding ne ""  && $inputencoding ne $outputencoding) {
	if ($inputencoding eq "Guess") {
	    require Encode::Guess;
	    $tmpenc=Encode::Guess::guess_encoding($_,qw/utf8/);
	    if (ref($tmpenc)) {
		$_=$tmpenc->decode($_);
	    }
	}
	else {
	    $_=Encode::decode($inputencoding,$_);
	}
	    
    }
    if ($outputencoding ne ""  && $inputencoding ne $outputencoding) {
	$_=Encode::encode($outputencoding,$_);
    }
    
    # cas des commentaires en format stm
    if ( /^;;/ && ($mask{stm}&$format_mask) ) { 
	if (! ($output_mask&$mask{txt})) {$outtext=$_;chop($outtext);} 
	else {$outtext="";}; $_=""; 
	goto PRINT;
    }


    #initialisation des champs
    $filename="";      # nom du fichier (format stm)
    $channel="";            # num�ro du canal (format stm)
    $speaker="";       # nom du locuteur (format stm)
    $startTime="";     # temps de d�but du segment (format stm)
    $endTime="";       # temps de fin du segment (format stm)
    $conditions="";    # conditions acoustiques (format stm)
    $text="";          # corps du texte � normaliser

    $outtext="";       # texte normalis�

    if ($format_mask&$mask{stm}) { # format stm
	s/^\s*//;
	chomp;
	@fields=split (/\s+/,$_,7);
	$filename   = shift @fields;
	$channel    = shift @fields;
	$speaker    = shift @fields;
	$startTime  = shift @fields;
	$endTime    = shift @fields;
	$conditions = shift @fields;
	$text       = shift @fields;
	if (! ($conditions =~ /\<.+\>/)) {
	    $text = "$conditions $text";
	    $conditions = "";
	}
	$_=$text;
    }

    if ($format_mask&$mask{lex}) { # format lex
	s/^\s*//;
	chomp;
	$filename="";
	$text="";
	$startTime="";
	$endTime="";
	if (s/^(.*)\((\S+)\-([0-9\.]+)\-([0-9\.]+)\)\s*$//) {
	    $filename=$2;
	    $text=$1;
	    $startTime=$3;
	    $endTime=$4;
	}
	$_=$text;
    }

    if ($format_mask&$mask{ctm}) { # format ctm
	s/^\s*//;
	chomp;
	@fields=split (/\s+/,$_);
	$filename   = shift @fields;
	$channel    = shift @fields;
	$startTime  = shift @fields;
	$duration   = shift @fields;
	$text       = shift @fields;
	$confidence = shift @fields; 
	$type       = shift @fields; 
	$speaker    = shift @fields; 
	if ($format_mask&$mask{ne}) {
	    if ($text=~s/(.*?)(--.*)/$1/) {
		$entity=$2;
	    } else {
		$entity="";
	    }
	}
	$_=$text;
	
    }

    if ($format_mask == $mask{ne}) { # format NE (entit�s nomm�es : 1 mot une cat�gorie)
	s/^\s*//;
	chomp;
	($text,$entity)=split (/\s+/,$_,2);
	$_=$text;

    }
   
    if ($format_mask&$mask{xml}) { 
#	$_.=$/;
#	print "(( $. $_ $scriptflag ";
	$completexml=$_;
	($_,$xmlterm)=split(/</,$_,2);
	if ($xmlterm ne "") {
	    $xmlterm='<'.$xmlterm;
	}
	if ($format_mask&$mask{html}) {
	    if ($xmlterm=~/<\!\-\-/) {
		$scriptflag++;
	    }
	    if ($xmlterm=~/<script/i) {
		$scriptflag++;

	    }
	    if ($xmlterm=~/\-\-\>/) {
#		print " !!! ";
		$_="";
		$scriptflag--;
	    }
	    if ($_=~s/<\!\-\-.*//) {
		$_="";
		$scriptflag++;
	    }
	    if ($_=~s/.*-->//) {
		$scriptflag--;
	    }

	    if ($xmlterm=~/<\/script/i) {
		$_="";
		$scriptflag--;
	    }
	}
#	print " $xmlterm $scriptflag ))\n\n\n\n";
    }


    
  TEXT:
    if ($format_mask&$mask{html} && $output_mask&$mask{txt}) {
	&htmlclean;
    }		
    if ($normalize_when eq "before" && $normalize) { $_=&normalize($_); }
# remplacement mot � mot dans le cas d'utilisation d'un dictionnaire
    @words=split(/\s+/m,$_); 
    @partial_match_ids=();
    $partial_match="";
    WORD:
    foreach $word (@words) { # traitement du dictionnaire
	if ((($normalize_when eq "before") && ($format_mask eq $mask{"stm-ne"}) && ($word=~s/^(\S+?)\-\-(.*)/$1/) ) || ($word =~ /(\S)/) ) { # mot ayant au moins un caract�re non blanc
	    my $tail=$2;
	    $outword="";
	    my $translation="";
	    my $tmp=$partial{"$word"};
	    $translation=$dico{@{$tmp}[0]};
	    if ($tail ne "") {
		$translation=~s/(\S)($|\s)/$1\-\-$tail$2/g;
	    }
	    if ($translation ne "") {
#		$matched{$word}=1;
		if ($tail ne "") {
		    $word.="--$tail";
		}
		&analyse_partial_match();
		if ($printunk ne 2) { 
		    $outword=$translation;
		}
		$count++;
		@partial_match_ids=();
		$partial_match="";
	    }
	    else {
		if ($#{$tmp} >= 0) {
#		    print "$word @{$tmp}[0] $translation\n";		
		    $partial_match.=" $word";
		    push(@partial_match_ids,$tmp);
		    push(@partial_words,$word); ###xxx
		    push (@partial_tails,$tail); ###xxx
		    next WORD;
		} else {
		    if ($tail ne "") {
			$word.="--$tail";
		    }
		    &analyse_partial_match();
		    @partial_match_ids=();
		    $partial_match="";
		    if ($skipunk eq 0) { 
			if ($printunk eq 1) { $outword="UNK";}
			else { $outword=$word; }
		    }
		
		    $unkdic{$word}++;
		    $global_unkdic{$word}++;
		    $nunk++;
		    $global_nunk++;
		}
	    }
	    if ($normalize && ($format_mask&$mask{ctm})) {
		$outword=~s/{/<ALT_BEGIN>/;
		$outword=~s/}/<ALT_END>/;
		$outword=~s/@//;
		$outword =~ s/\//<ALT>/;
	    }

	    if ($convertnum && (!$normalize)) { # conversion de chiffres en lettres quand pas de normalisation
		$wordtest=$outword+0;
		if ($outword=~/^[0-9]+$/) {
		    $outword=&numtolitteral($outword);
		    $outword=~s/^\s+//;
		    $outword=~s/\s+$//;
		    if ($normalize) {
			$outword=&normalize($outword);
		    }
		}
		elsif ($outword=~/^\(([0-9]+)(\-?)\)$/) {
		    $outword=&numtolitteral($1);
		    $outword=~s/^\s+//;
		    $outword=~s/\s+$//;
		    if ($normalize) { 
			$outword=&normalize($outword);
		    }
		    $outword=~s/\s+/\) \(/g;
		    $outword="($outword)";
		    $outword=~s/\(\(/\(/g;
		    $outword=~s/\)\)/\)/g;
               }		
		$outword=~s/\s+/$wordseparator/g;
		$lastoutword=$outword;
		$lastword=$word;
	    }
	    $outtext.=$outword.$wordseparator;
	}
	else { # gestion des espace entre les mots
	    $outword=$word;
	    if ($normalize) {
		$outword=~s/[^\n]//mg; # la normalization supprime les espaces et non les sauts de ligne
		if ($outword eq "") {
		    $outword=$wordseparator; # 
		}
	    }
	    $outtext.=$outword;
	}
    }
    if ($partial_match ne "")  {
	&analyse_partial_match();
    }
    if ($normalize_when eq "after" && $normalize) {
	$outtext=&normalize($outtext);
    }
    @outwords=split(/$wordseparator+/,$outtext);
    $noutwords=0;
    foreach $suboutword(@outwords) {
    	$count{$suboutword}++;
	$noutwords++;
	$global_count{$suboutword}++;
    }


    if ($format_mask&$mask{xml}) {
	if (! ($output_mask&$mask{txt})) {
	    if ($outtext ne "") { $front="";} else { $front="";}
	    $outtext.=$front.$xmlterm."";
	}
    }

    if (($format_mask&$mask{stm}) && (! ($output_mask&$mask{txt}))) { # formattage stm
	$outtext="$filename $channel $speaker $startTime $endTime $conditions ".$outtext;
	# remove multiple space from output (it happens when there is no conditions for example) 
	$outtext =~ s/\s+/ /g; 
    }

    if ($format_mask == $mask{lex}) {
	$outtext=~ s/\n//;
	$outtext="$outtext ($filename-$startTime-$endTime)\n";
    } 
    

    if ((($format_mask == $mask{ne}) && (! ($output_mask&$mask{txt})))) {
	$outtext="";
	if ($noutwords>0) {
	    foreach $suboutword(@outwords) {
		$outtext.=sprintf("%s %s\n",$suboutword,$entity);
	    }
	}
	else {
	    $outtext="";
	}
    }

    if (($format_mask&$mask{ctm}) && (! ($output_mask&$mask{txt}))) { # formattage ctm
	$outtext="";
	if ($noutwords>0) {
	    $localStartTime=$startTime;
	    $localDuration=$duration/$noutwords;
		foreach $suboutword(@outwords) {
		    if ($suboutword=~/ALT/) { # gestion des alternatives
			$noutwords=1;
			$localStartTime=$startTime;
			$localDuration=$duration;
			$outtext.=sprintf("%s %i * * %s\n",$filename,$channel,$suboutword);
		    }
		    else {
			if ($format_mask&$mask{ne}) {
			    $suboutword.=$entity;
			}
			$outtext.=sprintf("%s %i %.3f %.3f %s %.4f %s %s\n",$filename,$channel,$localStartTime,$localDuration,$suboutword,$confidence,$type,$speaker);
			$localStartTime+=$localDuration;
		    }
		}
	}
	else {
	    $outtext="";
	}


    }



  PRINT:
    if ($outtext ne "" && (($format_mask&$mask{stm}) || ($output_mask&$mask{txt} || ($output_mask&$mask{lex} ) )) ) { $EOL="\n";} else {$EOL="";}
    if (!$vocabulary_output) { print OFILE $outtext.$EOL; }
    $nline++;
}

if ($vocabulary_output && $output ne "-") {
    if ($printunk) {
	foreach $word (sort keys %unkdic) {
	    print OFILE "$count{$word}\t$word\n";
	}	
    }
    else {
	foreach $word (sort keys %count) {
	    print OFILE "$count{$word}\t$word\n";
	}
    }
}

close(FILE);
close(OFILE);


}

if ($vocabulary_output) {
    if ($printunk) {
	foreach $word (sort keys %unkdic) {
	    print STDERR "$global_count{$word}\t$word\n";
	}	
    }
    else {
	foreach $word (sort keys %count) {
	    print STDERR "$global_count{$word}\t$word\n";
	}
    }
}

$endtime=time();

if ($verbose) {
    $difftime=$endtime-$inittime;
    if ($difftime!=0) {
	print STDERR sprintf("$difftime seconds to process $nfiles files (%.2f f/s)\n",$nfiles/$difftime);#"$difftime seconds to process $nfiles files (".$nfiles/$difftime." f/s)\n";
    }
    else {
	print STDERR "less than 1 second to process $nfiles files\n";
    }
}

#procedure de protection des entites
sub protect_en() {
#    print STDERR "$startTime $endTime $_ \n";
#    print ">1 $_\n";
    if (   s/^([^\]\[]*(��[^\]\[]*)+\])/��$en_candidate_id/  ||
	   s/(\[[^\]\[]*(��[^\]\[]*)+\])/��$en_candidate_id/ ||
	   s/(\[[^\]\[]*(��[^\]\[]*)+)$/��$en_candidate_id/  ||
	   s/^([^\]\[]*\])/��$en_candidate_id/               ||
	   s/(\[[^\]\[]*\])/��$en_candidate_id/              ||
	   s/(\[[^\]\[]*)$/��$en_candidate_id/) {
	$protected{$en_candidate_id}=$1;
	my $tmp=$protected{$en_candidate_id};
	while ($tmp=~s/��([0-9]+)//) {
#	    $father{$1}=$en_candidate_id;
	    push(@{$sons{$en_candidate_id}},$1);
	}
	$en_candidate_id++;
	return 1;
    } 
    return 0;
}

sub replace_en_candidate() {
    my ($reptext,$id)=@_;
    my $content="";
    my $string=$protected{$id};
#    print STDERR "..$id $protected{$id}..\n";
    my @types;
    if ($string=~s/\[(\S+)\s*//) {
	@types=split("/",$1);
    } else { # EN en d�but de segment
	@types=@lasttypes;
	if ($#types < 0) {
	    $string=~s/\]\s*$//;
#	    $content=$string;
	    if ($string=~/\S/) {
		print STDERR "WARNING(normalize) : no start for entity : $filename $startTime $endTime $line\n";
	    }
	}
	$en_id{$filename}--;
    }
    if (!($string=~s/\s*\]//)) { # EN en fin de segment
	@lasttypes=@types;
	$renewed=1;
    } 
    $string=&normalize($string,($level+1));
    foreach $word (split(/\s/,$string)) {
	if ($convertnum) {
	    if ($word=~/^[0-9]+$/) {
		$word=&numtolitteral($word);
		$word=~s/^\s+//;
		$word=~s/\s+$//;
		$word=&normalize($word);
	    }
	    $word=~s/\s+/$wordseparator/g;
	}
	$content.="$word ";
    }
    
    if ($en_id{$filename} eq "") {
	$en_id{$filename}=0;
    }
#    print STDERR "****sons of $id ".join(" ",@{$sons{$id}})."\n";
    foreach my $id_son (@{$sons{$id}}) {
#	print STDERR "****sons : $id\n";
#	print STDERR ">".$content."\n" if ($#types<0);
	$content=&replace_en_candidate($content,$id_son);
    }
    if ($#types >= 0) {
	$type=join("/",@types);
	$content=~s/\s+/\-\-$type\-\-$en_id{$filename} /g;
	$en_id{$filename}++;
    }
#    $content=~s/%//;
#    print STDERR "$content > in $reptext\n" if ($#types<0);
    $reptext=~s/��$id($|\s)/$content/; 
#    print STDERR "out $reptext\n"  if ($#types<0);
    return $reptext;
}

#ajout au dictionnaire
sub addtodic() {
    my ($word,$translation)=@_;
    $translation_id++;
    if ($characterseparator ne "") {
	$translation =~ s/(.)/$1$characterseparator/g; 
    }
    if ($word=~/\s/) { # ajout version 0.48 traduction de mots compos�s
	$previous="";
	foreach $subword (split(/\s+/,$word)) {
	    push (@{$partial{"$subword"}},$translation_id."-"); # mots compos�s du dictionnaire
#			if ($previous ne "") {
#			    push (@{$partial{$previous.$subword}},$translation_id."-"); # mots compos�s du dictionnaire
#			}
	    $previous.="$subword ";
	}
	
	#	@{$partial{$subword}}[-1]="-".$translation_id;
    } else {
	push (@{$partial{"$word"}},"$translation_id");
    }
    $dico{"$translation_id"}=$translation;
    $input_word{"$translation_id"}=$word;
    if ($verbose) { print STDERR "'$word' => '$translation' ($translation_id) \n";}
    # also add to dico same words marked bad pronounced (*word)
    $translation_id++;
    $dico{"$translation_id"}=$translation;
    $input_word{"$translation_id"}="*$word";
    # also add to dico same words marked uncertain spell (^^word)
    $translation_id++;
    $dico{"$translation_id"}=$translation;
    $input_word{"$translation_id"}="^^$word";
#	    print "$word/$subword - $translation ($translation_id)\n";
}

# normalisation du texte
sub formatinit {
    if ($verbose && $firsttime) {
	print "initialisation des sp�cificit�s du format pour la normalisation\n";
	$firsttime=0;
    }

    if (($force_mask & $mask{ctm}) || ($format_mask & $mask{ctm})) {
	$altbegin='<ALT_BEGIN>';
	$alt='<ALT>';
	$altend='<ALT_END>';
	$optword='(%HESITATION)';
    } else {
	$filler='(%HESITATION)';
    }

    if ($normalize == 2) {
	foreach $hesit (euh, hum, huhum, mm) {
	    if ($force_mask&$mask{ctm}) {
		&addtodic($hesit, $altbegin.' '.$hesit.' '.$alt.' '.$optword.' '.$altend);
		if ($verbose) { print STDERR "rajout de la traduction normalis�e : $hesit => $dico{$hesit}\n"; }
	    } else {
		&addtodic($hesit,$filler);
		&addtodic("($hesit)",$filler);
		if ($verbose&&$firttime) { print STDERR "ajout de la traduction normalis�e : $hesit => $filler\n"; $firsttime=0; }
	    }
	}
    }
}

sub normalize {
    my ($text,$level)=@_;
    my $outputtext="";
    my @lines;
    $_=$text;
    @lines=split (/(\n)/,$text); #protection des sauts de ligne
#    my $line;
    foreach $line (@lines) {
	$currentline=$line;
	$_=$line;
#	print STDERR "**debut normalize:$_\n";
	if ($format_mask == $mask{"stm-ne"} && ($level < 1)) { #entit�s nomm�es
	    $en_candidate_id=0; # entit�s
	    %protected=(); # entit�s 
	    %sons=();      # entit�s imbriqu�es
	    @fathers=();
#	    print STDERR "**debut protect:$_\n";
	    while (&protect_en()) {}
#	    print STDERR "**mid protect:$_\n";
	    while (s/(��([0-9]+))/@@/) {
#		print ">>$2\n";
		push(@fathers,$2);
	    }
#	    print STDERR "**fin protect:$_\n";
	} 
	if ($_ ne "\n") {
	    if ( ( $format_mask & $mask{"stm"} ) && ! /ignore_time_segment_in_scoring/i ) {
		 s/([0-9]),([0-9])/$1 virgule $2/g; #remplace 2,3 par 2 virgule 3
		 s/([0-9])\.([0-9])/$1 point $2/g; #remplace 2.3 par 2 point 3
		 while ($convertnum && /([^�]|\s|^)[0-9]+/) {
		     s/\s+([0-9]+)/" ".&numtolitteral($1)." " /egs; # conversion chiffre en lettres
		     s/^([0-9]+)/" ".&numtolitteral($1)." " /egs; # conversion chiffre en lettres
		     s/([^�])([0-9]+)/$1." ".&numtolitteral($2)." " /egs; # conversion chiffre en lettres
		 }
		 s/\.//g; # supprime les points
		 s/\"//g;  # supprime les guillemets
		 s/,//g;   # supprime les virgules
		 s/\^+//g; # supprime les ^^ (mots � orthographe incertaine)
		 s/\*(?)/$1/g; # supprime les * (mots mals prononc�s)	
		 s/://g;   # supprime les :  
		 s/_/ /g;  # supprime les underscores
		 s/\-/ /g; # supprime les tirets
		 s/(\s|^)([cdjlmnstyL]|jusqu|lorsqu|puisqu|qu|quelqu|quoiqu)\'/$1$2\' /g; # ex: d'une => d' une
		 s/\///g;s/\\//g; # supprime les slash (/) et anti-slash (\)
		 s/\(([^\)%]+)\)/\(\)/g; # supprime l'int�rieur des parenth�ses : (aux)quell(es) => ()quell()
		 while(s/(\s+|^)\(\)([^\s]+)\(\)(\s+|$)/$1\(\-$2\-\)$3/) {}; # ()quell() => (-quell-)
		 while(s/(\s+|^)\(\)([^\s]+)(\s+|$)/$1\(\-$2\)$3/) {}; # ()quelles => (-quelles)
		 while(s/(\s+|^)([^\s]+)\(\)(\s+|$)/$1\($2\-\)$3/) {}; # aux() => (aux-)
		 s/(\s*)\(\)(\s*)/$1$3/g; # supprime les ()	
		 s/\?//g;  # supprime les points d'interrogation
		 s/(.*)\!/$1 \!/g; #d�cole tous les points d'exclamation
		 s/AC\s\!/AC\!/g;s/Yahoo\s\!/Yahoo\!/g; #reconstitue AC! et Yahoo!
		 s/\s\!/ /g; # supprime les points d'exclamation pr�c�d�s d'un espace
		 s/(\s|^)([a-z]+)\!/$1$2/g; # supprime les points d'exclamation coll�s sauf ceux de marques (ex AC! ou Yahoo!)
		 s/^!//g; #supprime les ! de d�but de ligne 
		 s/\[[^\]]*\]//g; #supprime les commentaires
		 s/\;//g;  # supprime les ;
		 s/([a-z])\%/$1 %/g; # ins�re un espace entre le % et le mot pr�c�dent
		 s/\%($|\s)/pour cent$1/g; # remplace % par pour cent s'ils sont suivis d'un espace
		 s/([^\(]|^)\%//;  # remplace les cha�nes "%mot" par "mot"
		 s/\s+/ /g; # supprime les espaces mutliples par un seul 
		 s/^\s//g;  #supprime l'espace de d�but de ligne
		 s/\s$//g;  # supprime l'espace de fin de ligne
#		 if (($format_mask == $mask{"stm-ne"})&&($level<1)) { # mots hors entit�s nomm�es optionnels
#		     s/(^|\s+)([^\@ ]+)/$1\($2\)/g; 
#		 } 
	    }
		       if ($format_mask == $mask{lex}) { # format lex
			   while ($convertnum && /[0-9]+/) {
			       s/([0-9]+)/" ".&numtolitteral($1)." " /egs; # conversion chiffre en lettres
			   } 
			   s/\.//g; # supprime les points
			   s/\"//g;  # supprime les guillemets
			   s/,//g;   # supprime les virgules
			   s/://g;   # supprime les :  
			   s/_/ /g;  # supprime les underscores
			   s/((\-t)?\-(il|elle|on|ils|elles|tu|le|la|l�|vous|nous|je))($|\s+)/ $1 /g; # -t-il
			   s/(\s|^)([cdjlmnstyL]|jusqu|lorsqu|puisqu|qu|quelqu|quoiqu)\'/$1$2\' /g; # ex: d'une => d' une
			   s/\///g;s/\\//g; # supprime les slash (/) et anti-slash (\)
			   s/(^|\s+)\([^\)]*\)($|\s+)/ /g; # supprime les (.*) isol�s
			   s/\?//g;  # supprime les points d'interrogation
			   s/(.*)\!/$1 \!/g; #d�cole tous les points d'exclamation
			   s/AC\s\!/AC\!/g;s/Yahoo\s\!/Yahoo\!/g; #reconstitue AC! et Yahoo!
			   s/(^|\s)\!/ /g; # supprime les points d'exclamation pr�c�d�s d'un espace ou en d�but de ligne
			   s/(\s|^)([a-z]+)\!/$1$2/g; # supprime les points d'exclamation coll�s sauf ceux de marques (ex AC! ou Yahoo!)
			   while (s/(\[[^\]]*)\s+([^\]]*\])/$1\_$2/) {} # suppression des espaces � l'int�rieur des crochets
#			   s/(\[|\])//g; #supprime les [ et ]
#			   s/(\(|\))//g; #supprime les ( et )
			   s/\;//g;  # supprime les ;
			   s/\s+/ /g; # supprime les espaces mutliples par un seul 
			   s/^\s//g;  #supprime l'espace de d�but de ligne
			   s/\s$//g;  # supprime l'espace de fin de ligne
		       }
	    if ($format_mask & $mask{ctm} || $format_mask == $mask{txt}) { # format ctm ou txt
		     while ($convertnum && /[0-9]+/) {
		         s/([0-9]+)/" ".&numtolitteral($1)." " /egs; # conversion chiffre en lettres
		     }
		     s/\.//g; # supprime les points
		     s/\"//g;  # supprime les guillemets
		     s/,//g;   # supprime les virgules
		     s/\^+//g; # supprime les ^
		     s/\*+//g; # supprime les * 
		     s/://g;   # supprime les :  
		     s/_/ /g;  # supprime les underscores
		     s/\-/ /g; # supprime les tirets
    		     s/(\s|^)([cdjlmnstyL]|jusqu|lorsqu|puisqu|qu|quelqu|quoiqu)\'/$1$2\' /g; # ex: d'une => d' une
		     s/\///g;s/\\//g; # supprime les slash (/) et anti-slash (\)
		     s/(\s*)\(\)(\s*)/$1$3/g; # supprime les ()	
		     s/\?//g;  # supprime les points d'interrogation
		     s/(.*)\!/$1 \!/g; #d�cole tous les points d'exclamation
		     s/AC\s\!/AC\!/g;s/Yahoo\s\!/Yahoo\!/g; #reconstitue AC! et Yahoo!
		     s/\s\!/ /g; # supprime les points d'exclamation pr�c�d�s d'un espace
		     s/(\s|^)([a-z]+)\!/$1$2/g; # supprime les points d'exclamation coll�s sauf ceux de marques (ex AC! ou Yahoo!)
		     s/^!//g; #supprime les ! de d�but de ligne 
		     s/(\[|\])//g; #supprime les [ et ]
		     s/(\(|\))//g; #supprime les ( et )
    		     s/\;//g;  # supprime les ;
		     s/\s+/ /g; # supprime les espaces mutliples par un seul 
		     s/^\s//g;  #supprime l'espace de d�but de ligne
		     s/\s$//g;  # supprime l'espace de fin de ligne
          }			       
	}
        $outputtext=$_;
	if ($format_mask == $mask{"stm-ne"}&& ( $level < 1)) { #entit�s nomm�es
	    $renewed=0;
#	    print STDERR "**debut replace:$outputtext *".join("*",@fathers)."\n";
	    foreach my $replace_id (@fathers) {
#		print STDERR "<<>>$replace_id\n";
#		print STDERR "*mid1 replace: $outputtext\n";
		$outputtext=~s/@@/��$replace_id/;
#		print STDERR "*mid2 replace: $outputtext\n";
		$outputtext=&replace_en_candidate($outputtext,$replace_id);
#		print STDERR "*mid3 replace: $outputtext\n";
	    }
#	    print STDERR "**fin replace:$outputtext\n";
	    if ($renewed eq 0) {
		@lasttypes=();
	    }
	}
	if ($format_mask != $mask{lex}) {
	  $outputtext=lc($outputtext); 
        }
    }	
#		 print "**fin normalize : $outputtext\n";
    return $outputtext;
    
}

#analyse des matchs partiels (mots compos�s du dictionnaire)
sub analyse_partial_match() { # en cours de d�veloppement
    return if ($partial_match eq "");
    my %count=();
#    @partial_tails=grep {++$count{$_}<2} @partial_tails; ###xxx
    my $tail_id=0;
    $partial_match=~s/^\s+//;$partial_match=~s/\s+$//;    
#    print $partial_match."\n";
#    @partial_match_ids =  grep { ++$count{$_}<2 } sort numerically map { s/\-//;$_; } @partial_match_ids;
    for (my $i=0;$i<=$#partial_match_ids;$i++) {
	foreach my $m (@{@partial_match_ids[$i]}) {
	    my $match=$m;
	    $match=~s/\-$//;
	    my $tmp1=$input_word{$match};
	    my $tmp2=$dico{$match};
#	    print "$partial_match : '$tmp1' : '$tmp2'\n";
#	    print "index:".index($tmp1,$partial_match)."\n";
	    if ($partial_match=~s/^$tmp1($|\s+)//) {
		if (($format_mask eq $mask{"stm-ne"}) && (@partial_tails[$i] ne "") ) {
		    my $tmp3=@partial_tails[$i]; ###xxx
		    $tmp2=~s/([^\{\}\/ ])($|\s+)/$1\-\-$tmp3 /g; ###xxx
		}
		$outtext.=$tmp2.$wordseparator;
		my @tmp_table=split(/ /,$tmp1);
		$i+=$#tmp_table;
		goto NEXT_MATCH;
	    } 
	}
#	print "ici $partial_match @partial_tails[$i]\n";
	if (($format_mask eq $mask{"stm-ne"}) && (@partial_tails[$i] ne "") ) { ###xxx
#	    print "ici aussi\n";
	    $partial_match=~s/^@partial_words[$i]\s*//; ###xxx
	    $outtext.=@partial_words[$i]."--".@partial_tails[$i].$wordseparator; ###xxx
	    goto NEXT_MATCH;
	} ###xxx
	$partial_match=~s/(\S+)\s*//;
	$outtext.=$1.$wordseparator;
      NEXT_MATCH:
	$i=$i;
    }
 #   foreach my $list_match (@partial_match_ids) {
#	$i++;

    #}
    @partial_tails=(); ###xxx
    @partial_match_ids=();
    @partial_words=();
    $partial_match="";

#    $outtext.=$partial_match.$wordseparator;
}

#french num to letteral conversion
#french num to letteral conversion

sub numtolitteral {
  my @num = (); # split input string into an array of digits
  my $sol = undef;
  my $len = undef;

  my $cent = undef;
  my $mille = undef;
  my $million = undef;
  
  my $str = shift;
  $str =~ s/^0*//;
  @num = reverse split(//, $str);
  $len = scalar @num;

  return "z�ro" if not $len;

  $cent = join("", reverse splice @num, 0, 3);
  $mille = join("", reverse splice @num, 0, 3);
  $million = join("", reverse splice @num, 0, 3);

  if ($len <= 3) {
    $sol = dtoa("z�ro", $cent, 1);
  }
  elsif ($len >= 4 and $len <= 6)  {
    $sol = "";
    $sol = dtoa("", $mille, 0) unless $len == 4 and $mille == 1;
    $sol = join(" ", $sol, "mille", dtoa("", $cent, 1));
  }
  else {
    $sol = join(" ", dtoa("", $million, 1), "million");
    $sol = $sol . "s" if $million > 1;
    my $tmp = "";
    $tmp = dtoa("", $mille, 0) unless $mille == 1;
    $sol = join(" ", $sol, $tmp, "mille") unless $mille == 0;
    $sol = join(" ", $sol, dtoa("", $cent, 1));
  }
  $sol =~ s/\s+/ /g;
  return $sol;
}

# --------------------- #
# ---- sub dtoa() ----- #
# --------------------- #
sub dtoa() {
  my $zero = shift;
  my @tab = split(//, shift);
  my $final = shift;
  my $sol = "";

  my @digit = qw(z�ro un deux trois quatre cinq six sept huit neuf);
  my @digit1x = qw/dix onze douze treize quatorze quinze seize dix-sept dix-huit dix-neuf/;
  my @digitx0 = ("", "dix", "vingt", "trente", "quarante", "cinquante", "soixante", "soixante-dix", "quatre-vingt", "quatre-vingt-dix");

  # remove heading zeros...
  shift @tab while $tab[0] == 0 and $#tab > 0;
  my $len = scalar @tab;

  if ($len == 1) { # [0-9]
    $sol = $digit[$tab[0]];
    $sol = $zero if $tab[0] == 0;
  }
  else {
    $sol = "";
    if ($len == 3) {
      my $c = shift @tab;
      $sol = $digit[$c] unless $c == 1;
      $sol = join(" ", $sol, "cent");
      $sol = $sol . "s" if $c > 1 and $tab[0] == 0 and $tab[1] == 0 and $final;
    }
    
    # convert 2 digits @tab to string
    my $d2 = "";
    if ($tab[0] == 0) {
      $d2 = $digit[$tab[1]] if $tab[1];
    }
    elsif ($tab[0] == 1) {
      $d2 = $digit1x[$tab[1]];
    }
    else {
      if ($tab[1] == 0) {
	$d2 = $digitx0[$tab[0]];
	$d2 = $d2 . "s"  if $tab[0] == 8 and $tab[1] == 0 and $final; 
      }
      else {
	if ($tab[0] == 7 or $tab[0] == 9) {
	  $d2 = join("-", $digitx0[$tab[0] - 1], $digit1x[$tab[1]]);
	  $d2 = join("-", $digitx0[$tab[0]-1], "et", $digit1x[$tab[1]]) if $tab[0] == 7 and $tab[1] == 1;
	}
	else {
	  $d2 = $digitx0[$tab[0]];
	  $d2 = $d2 . "s"  if $tab[0] == 8 and $tab[1] == 0 and $final; 
	  $d2 = $d2 . "-et" if $tab[1] == 1 and $tab[0] != 8;
	  $d2 = join("-", $d2, $digit[$tab[1]]);
	}
      }
    }

    $sol = join(" ", $sol, $d2);
  }

  return $sol;
}

sub numerically () {
    a <=> b
}

sub encodingtest () {
    my ($encoding)=@_;
    require Encode;
    if ($encoding =~ /^Guess$/) {
	return 1;
    }
    else {
	
	if (Encode::resolve_alias($encoding)) {return 1;}
	@all_encodings = Encode->encodings(":all"); 
	foreach $known_encoding (@all_encodings) {
	    if ($encoding eq  $known_encoding) {
		return 1;
	    }
	}
    }
    return 0;
}


sub htmlclean {
    if ($scriptflag>0) {
	$_="";
    } else {
	$_=~s/^\s+$//;
	s/&nbsp;/ /g;
	if (/\&/) {
	    foreach $SymbLine (&HTMLSymb) {
		($ascii, $html) = split(/\s\s*/,$SymbLine);
		$_ =~ s/$html/$ascii/g;
	    }	
	}
    }
}


	
    
sub HTMLSymb {

	return ( 
	"&	&amp;",
	"\"	&quot;",
	"<	&lt;",
	">	&gt;",
	"�	&copy;",
	"�	&reg;",
	"�	&AElig;",
	"�	&Aacute;",
	"�	&Acirc;",
	"�	&Agrave;",
	"�	&Aring;",
	"�	&Atilde;",
	"�	&Auml;",
	"�	&Ccedil;",
	"�	&ETH;",
	"�	&Eacute;",
	"�	&Ecirc;",
	"�	&Egrave;",
	"�	&Euml;",
	"�	&Iacute;",
	"�	&Icirc;",
	"�	&Igrave;",
	"�	&Iuml;",
	"�	&Ntilde;",
	"�	&Oacute;",
	"�	&Ocirc;",
	"�	&Ograve;",
	"�	&Oslash;",
	"�	&Otilde;",
	"�	&Ouml;",
	"�	&THORN;",
	"�	&Uacute;",
	"�	&Ucirc;",
	"�	&Ugrave;",
	"�	&Uuml;",
	"�	&Yacute;",
	"�	&aacute;",
	"�	&acirc;",
	"�	&aelig;",
	"�	&agrave;",
	"�	&aring;",
	"�	&atilde;",
	"�	&auml;",
	"�	&ccedil;",
	"�	&eacute;",
	"�	&ecirc;",
	"�	&egrave;",
	"�	&eth;",
	"�	&euml;",
	"�	&iacute;",
	"�	&icirc;",
	"�	&igrave;",
	"�	&iuml;",
	"�	&ntilde;",
	"�	&oacute;",
	"�	&ocirc;",
	"�	&ograve;",
	"�	&oslash;",
	"�	&otilde;",
	"�	&ouml;",
	"�	&szlig;",
	"�	&thorn;",
	"�	&uacute;",
	"�	&ucirc;",
	"�	&ugrave;",
	"�	&uuml;",
	"�	&yacute;",
	"�	&yuml;",
	" 	&#160;",
	"�	&#161;",
	"�	&#162;",
	"�	&#163;",
	"�	&#165;",
	"�	&#166;",
	"�	&#167;",
	"�	&#168;",
	"�	&#169;",
	"�	&#170;",
	"�	&#171;",
	"�	&#172;",
	"�	&#173;",
	"�	&#174;",
	"�	&#175;",
	"�	&#176;",
	"�	&#177;",
	"�	&#178;",
	"�	&#179;",
	"�	&#180;",
	"�	&#181;",
	"�	&#182;",
	"�	&#183;",
	"�	&#184;",
	"�	&#185;",
	"�	&#186;",
	"�	&#187;",
	"�	&#188;",
	"�	&#189;",
	"�	&#190;",
	"�	&#191;",
	"�	&#215;",
	"�	&#222;",
	"�	&#247;",
        "�      &#224;",
	"�      &#233;",
	"�      &#234;",
	"�      &#231;",
	"\'     &#39;",
	"\"     &#34;",
	"�      &#232;",
        "�     &#238;",
        "�     &#244;",
	"     &#160;",
	"�    &#251;",
	"� &#235;",
	"� &#251;",
	"� &#239;",
	"� &#201;",
	"� &#192;",	 
"� &#200;",
"� &#202;",
"�  &#206;",
"� &#249;",
"� &#226;",
"� &#207;",
"oe &#156;",
"OE &#338;",
"� &#203;",
"� &#212;",
"� &#38;Acirc",
"� &#246;",
   "  &#150;",
   "� &#194;",
   "A &#196;",
   "� &#199;",
   "� &#214;",
   "� &#217;",
   "� &#219;",
   "� &#220;",
   "� &#225;",
   "� &#227;",
   "� &#237;",
   "� &#241;",
   "� &#242;",
   "� &#243;",
   "� &#250;",
   "� &#252;",
   "� &#255;",
   "& &#38;",
   "-  &#45;",
   "� &#8364;",
   "\[ &#91;",
   "\]  &#93;",

)
}


__END__

=head1 NAME

normalize - v0.56 - normalisation de textes en fran�ais (written for ESTER by DGA/FAE & DGA/SGO )

=head1 SYNOPSIS

normalize [-help|h] [-verbose|v] [-input|i input_file_format] [-output|o output_file_format] [-b batch_file] [postprocess|p=s post-processing_command] [inputencoding|ie input_encoding] [outputencoding|oe output_encoding] [inputformat|if input_format] [outputformat|of output_format] [-normalize|n] [-numtolietterals|l] [-dictionary|d dictionary_file]  [-dictionaryseparator|ds=s dictionary_separator] [-skipunknown|s] [-printunknown [mode]] [-wordseparator|w word_string_separator] [-characterseparator|c character_string_separator] [file1 file2 ...]
  
Description :

    normalize (v0.56) normalise des fichiers au format texte, xml ou stm (NIST)

Typical usage :

    normalize file.xml -n -l -o %s.norm.xml

    normalise le fichier xml 'file.xml' (retrait de la ponctuation, des '-'), convertit les
    chiffres en lettre et �crit le r�sultat dans le fichier 'file.norm.xml'.

    cat file.xml | normalize -n -l -v

    normalise le fichier 'file.xml' depuis STDIN, normalise, et �crit le vocabulaire
    dans STDOUT.

pour plus d'aide :

    normalize -man

=head2 Mises � jour

=over 8

=item B<-Nouveaut�s version 0.56>
    - correction d'un bug sur entit� imbriqu�es d�cal�es et d�coup�es
    - warning sur entit�s non ouvertes.

=item B<-Nouveaut�s version 0.54>
    - normalisation stm-ne : rapprochement vers le format stm (mots non optionnels)
    - bug : application du dictionnaire d'�quivalence aux EN

=item B<-Nouveaut�s version 0.53>
    - prise en compte des mots multiples pour le format stm
    - correction de bugs
    - d�claration de formats dans les dictionnaires (pour s�paration des traitements ctm/stm    

=item B<-Nouveaut�s version 0.51>
    - support du format .lex (normalisation sp�cifique � ce format)

=item B<-Nouveaut�s version 0.50>
    - mise � jour pour les formats ctm-ne et stm-ne
    - correction de bug : output dans un seul fichier maintenant possible

=item B<-Nouveaut�s version 0.49>
    - corrections de bugs


=item B<-Nouveaut�s version 0.48>
    - corrections de bugs
    - support des expressions compos�es dans le dictionnaire (mot1 mo2 => mot3 mot4), et remplacement du caract�re de s�paration par '\s*=>\s*'
    - possibilit� de normalizer avant ou apr�s le passage du dictionnaire (par d�faut : apr�s)

=item B<-Nouveaut�s version 0.47>

    - correction de bugs
    - support des format stm-ne et ctm-ne (entit�s nomm�es)
    - corrections diverses de normalisation
    - changement des param�tres par d�faut (normalisation et conversion chiffres-lettres par d�faut, il faut utiliser l'option -n 0 pour ne pas normaliser et -l 0 pour ne pas convertir les chiffres en lettre)

=head1 OPTIONS

=over 8

=item B<-help>

    Renvoie une aide consise, et sort du programme.

=item B<-man>

    Renvoie cette page de manuel.

=item B<-verbose|v>
    
    R�sultat d�taill�. En particulier, affiche les noms de fichiers
    en cours de traitement.

=item B<-input|i inpput_file_format>

    Pour normaliser plusieurs fichiers, vous pouvez utiliser un formattage des
    noms pour simplifier les lignes de commande.

    Exemple :

    normalize -n -l file1 file2 ... file_n -i input_dir/%s.xml

    normalise 'input_dir/file1.xml', 'input_dir/file2.xml', ... 'input_dir/file_n.xml'
    (r�sultat dans STDOUT).


=item B<-output|o output_file_format>

    Pour sauvegarder la sortie fichier par fichier.

    Exemple :

    normalize -n -l input_dir/*.xml -o output_dir/%s.ext

    traite chaque fichier *.xml dans 'input_dir/'
    et sauve le r�sultat dans 'output_dir/' en rempla�ant
    l'extension de fichier 'xml' par 'ext'.

=item B<-batchfile|b batch_file>

    Pour traiter les fichier d'une liste 'batch_file'.

    Exemple 1:

    supposons que nous avons dans 'batch_file' la liste suivante :
    'input_dir_1/file_1
     input_dir_2/file_2
     ...
     input_dir_n/file_n'
    
    alors :

    normalize -n -l -b batch_file

    traite chaque fichier de la liste 'input_dir_n/file_i', et donne
    le r�sultat dans la sortie standard STDOUT.

    Exemple 2:

    supponsons maintenant que nous avons dans 'batch_file' :
    'file_1.xml
     file_2.xml
     ...
     file_n.xml'

    alors :

    normalize -t txt -n -l -b batch_file -i input_dir/%s -o output_dir/%s.txt

    traite tous les fichiers list�s dans 'batch_file' et situ�s dans le
    r�pertoire 'input_dir'. Chaque fichier d'entr�e donne un fichier
    r�sultat au format texte (option -t txt) qui est enregistr� dans 'output_dir'
    avec l'extension '.txt' au lieu de '.xml'

    Exemple 3:

    supposons que nous avons maintenant une liste � deux entr�es dans 'batch_file' :
    'ifile_1    ofile_1
     ifile_2    ofile_2
     ...
     ifile_n    ofile_n'

    alors :

    normalize -n -l -b batch_file -i input_dir/%s -o output_dir/%s.txt
    
    traite chaque fichier 'input_dir/ifile_i' et enregistre le r�sultat dans
    'output_dir/ofile_i.txt'


=item B<-postprocess|p post-processing_command>

    Effectue le post-traitement 'processing_command' avant d'�crire le ou les
    fichier(s) de sortie (utiliser avec l'option -o, ne fonctionne pas avec la 
    sortie standard).

    Exemple :
    
    normalize -n -l -v input_dir/*.xml -o output_dir/%s.voc -p "sort -nr"

    �crit le vocabulaire de chaque fichier 'input_dir/*.xml' dans
    'output_dir/*.voc' tri� par occurence.

=item B<-inputencoding|ie input_encoding>

    Sp�cifie l'encodage d'entr�e 'input_encoding',
    par exemple 'utf-8' ou 'UTF8' pour unicode sur 8 bits.
    Pour un document xml, l'encodage est g�n�ralement pr�cis�
    dans l'ent�te. Utilisez cette option pour outrepasser l'encodage
    sp�cifi� dans l'ent�te.

=item B<-outputencoding|oe output_encoding>
    
    Sp�cifie l'encodage de sortie 'output_encoding' 
    Par d�fault, l'encodage de sortie est celui de l'entr�e.

=item B<-inputformat|if input_format>

    Sp�cifie le format d'entr�e 'input_format', par exemple
    'xml', 'html', 'text' ou 'stm'. Si aucun format  d'entr�e
    n'est sp�cifi�, le programme essaye de le deviner.

=item B<-outputformat|of output_format>

    Sp�cifie le format de sortie 'output_format', par exemple
    'text' pour une sortie de texte brute, 'vocab' pour le
    vocabulaire.

=item B<-normalize|n [mode]>

    Utiliser cette option pour normaliser le texte d'entr�e
    en enlevant les espaces multiples, signes de ponctuation,
    et autres marques (comme '-'). 'mode' est un nombre entier
    optionnel qui d�signe le niveau de normalisation.

       mode       normalisation
       1          h�sitations non optionnelles
       2          h�sitations optionnelles mais diff�renci�es :
                             euh, hum, huhum

=item B<-numtolitterals|l>

    Convertit les chiffres en lettre (en fran�ais). Par exemple,
    '1981' donnera 'mille neuf cent quatre-vingt-un'.

=item B<-dictionary|d dictionary_file>

    Utilise le dictionnaire 'dictionary_file' pour faire une traduction
    mot � mot. Utile pour avoir les mots hors vocabulaire (OOV) avec l'option
    '-of vocab'.

    Format du dictionnaire d'entr�e par d�faut (cf option -dictionnaryseparator) : suite de lignes de type '(\S+)\s+.*'.

=item B<-dictionnaryseparator|ds dictionnary_string_separator>

    Utilise 'dictionnary_string_separator' comme cha�ne de s�paration entre les mots du dictionnaire et leur traduction.
    Cha�ne par d�faut : '\s+'
    Exemple : 
    Si le format d'entr�e du dictionnaire est :
    mot1 => traduction1
    mot2 => traduction2

    utiliser l'option -ds '\s*=>\s*'
    La cha�ne doit �tre conforme � la syntaxe des expressions r�guli�res en Perl.


=item B<-skipunknown|s>

    Combin�e avec l'option '-d', cette option retire les mots hors vocabulaire.
    Combin�e avec l'option '-of v', liste les mots du vocabulaire avec leur d�compte.

=item B<-printunknown|u [mode]>

    Remplace les mots hors vocabulaire par 'UNK' si aucun mode n'est sp�cifi�, ou si
    le mode 1 est utilis�.
    Si 'mode' vaut 2, supprime simplement les mots hors vocabulaire.
    Avec l'option '-of v', liste les mots hors vocabulaire avec leur d�compte.

=item B<-wordseparator|w word_string_separator>

    Utilise la cha�ne de caract�res 'word_string_separator' entre les mots.

=item B<-characterseparator|c character_string_separator>

    Utilise la cha�ne de caract�res 'chararcter_string_separator' entre les lettres des mots.
    Peut �tre utile pour une phon�tisation par exemple (hors contexte).

=back


=cut








