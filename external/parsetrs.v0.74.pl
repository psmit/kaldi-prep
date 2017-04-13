#!/usr/bin/perl


use Getopt::Long;
use Pod::Usage;

$inittime=time();

$version="0.74";
$verbose=0;
$warning=0;
$nfiles=0;
$printevent=0;
$printspeaker=1;
$printseg=1;
$removesegment=0;
#format initialisation
foreach $balise (qw/trans speaker topic episode section turn sync background event comment who transcription/) {
    $proceed{$balise}=1; # si mis � 0, les balises � 0 ne sont pas regard�es
}
$outputformat="stm";
$norm{speaker}=0;
$format{default_transcription}="";
$format{notrans_topic}="<no_trans>";
$format{notrans_speaker}="<no_speaker>";
$format{notrans_transcription}="";
$format{nospeaker_transcription}="";
$format{nospeaker_topic}="<no_trans>";
$format{nospeaker_speakername}="<no_speaker>";
$format{speaker_speechstart}="%speech_start{%active_speaker_id}";
$format{speaker_duration}="%speech_start{%active_speaker_id}";
$format{speaker_speech}="%speech{%active_speaker_id}";
undef($format{nospeech_transcription});

$format{background}="";
$format{separator}=" ";
$format{episode}="%sections";
$format{section}="%turns";
$format{turn}="%syncs";
$format{sync}="%transcription (%speaker-%conditions) (%topic) (%filename-%begin-%end)";


$format{speaker}="%speakername-%speakerdialect-%speakeraccent-%speakergenre";
$format{speakername}="%name{%speakerid}";
$format{speakercheck}="%check{%speakerid}";
$format{speakergenre}="%genre{%speakerid}";
$format{speakerdialect}="%dialect{%speakerid}";
$format{speakeraccent}="%accent{%speakerid}";
$format{speakerscope}="%scope{%speakerid}";
$format{unchecked_speaker}="%filename_%speakername";
$format{nospeech_speaker}=$format{speaker};

$format{num}="%f";

$format{event}="[%event_type:%event_desc]";
$format{event_begin}="[%event_type:%event_desc-]";
$format{event_end}="[%event_type:-%event_desc]";
$format{noeventtype_event}="[noise:%event_desc]";
$format{noeventtype_event_begin}="[noise:%event_desc-]";
$format{noeventtype_event_end}="[noise:-%event_desc]";
$format{comment}='[comment:%comment_desc]';
$format{topicdesc}="%topic_desc{%topicid}";

#initialisations
$overlappingevent="";
$overlappingbackground="";
$case=0;
$totaspeechduration=0;
$output="-";
$ignoring_flag="no";
$cut=0;
@patterns1=();
@patterns2=();
@patterns3=();
@patterns4=();
#----------------------------

#lecture des arguments
#-----------------------
GetOptions( 'outputformat|f=s'        => \$outputformat,
	    'execformat|ef=s'               => \$execformat,
	    'printevent|c'          => sub {$printevent=1;},
	    'verbose|v'               => \$verbose,
	    'warning|w'               => \$warning,
	    'uppercase|u'             => sub {$case=1;},
	    'lowercase|l'             => sub {$case=2;},
	    'output|o=s'              => \$output,
	    'postprocess|p=s'         => \$postprocess,
	    'keepaudiofilename|k'      => \$keepaudiofilename,
	    'help|h'                  => \$help,
            'input|i=s'               => \$input,
	    'batch|b=s'               => \$batchfile,
	    'removecontent|rmc=s'     => \$ignorecontent,
	    'removetag|rmt=s'         => \$ignoretag,
	    'removesegment|rms=s'     => \$ignoresegment,
	    'extract|e=s'             => \$extract,
	    'respectcut|r'            => sub {$cut=1},
	    'man'                     => \$man
	    ) or exit(1);

pod2usage(0) if ( $help ); 
pod2usage(1) if $man;

# prise en compte des fichiers d'entree/sortie
$nargs=$#ARGV+1; # le reste des arguments est pris comme noms de fichiers d'input a parser
ARGUMENT :  
    for ($j=0;$j<$nargs;$j++) { #fichiers a� parser
	$arg=@ARGV[$j];
	$files[$nfiles]=$arg;
	$nfiles++;

    }
    if ($nfiles==0) {
	$nfiles=1;
	$files[0]="-";
    }
if ($batchfile ne "") { #lecture du fichier batch pour traitement de fichiers multiples
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
    
    &verbose("$nfiles in batchfile");
}
#----------------- fin de la lecture du fichier batch
#----------------- fin de la prise en compte des fichiers d'entree/sortie
    
if ($postprocess ne "") { # option de postprocessing des fichiers
    $ocmd = "| $postprocess ";
}

if ($outputformat) { # prise en compte du format des fichiers de sortie
    &initformat(); # initialisation du format (stm, lexh, text, ...) cette initialisation peut contenir des param�tres particuliers (-i, -c)
}


# prise en compte des elements a supprimer ou ignorer
if ($ignorecontent) { # initialisation des patterns de commentaires et events � supprimer (suppression du contenu de l'event)
    @patterns1=split(/,/,$ignorecontent);
    foreach $pattern (@patterns1) {
	$ign_content{$pattern}=1;
    }
    $ignore=1;
    &verbose("ignoring $ignorecontent");
}
if ($ignoresegment) { # initialisation des patterns de commentaires et events � supprimer (suppression des segment content l'event)
    @patterns2=split(/,/,$ignoresegment);
    foreach $pattern (@patterns2) {
	$ign_segment{$pattern}=1;
    }
    $ignore=1;
    &verbose("ignoring segment for $ignoresegment");
}
if ($ignoretag) { # initialisation des patterns de commenttaires et events � supprimer (suppression des balises de l'event)
    @patterns3=split(/,/,$ignoretag);
    foreach $pattern (@patterns3) {
	$ign_tag{$pattern}=1;
    }
    $ignore=1;
    &verbose("ignoring tag for $ignoretag");
}
if ($extract) { # initialisation des patterns de commentaires et events � extraire exclusivement
    @patterns4=split(/,/,$extract);
    foreach $pattern (@patterns4) {
	$ext_tag{$pattern}=1;
    }
    &verbose("extracting $extract");
}
@patterns=(@patterns1,@patterns2,@patterns3,@patterns4);
#------------- fin du traitement des elements a supprimer ou a extraire

#-----fin lecture & traitement des arguments

#corps de la fonction parsetrs
$nfile=0;
if (!($output=~/%s/)) { # cas d'un fichier unique de sortie : nettoyage de ce fichier
    open (OFILE, ">$output");
    print OFILE "";
    close OFILE;
}

while($nfile<$nfiles) { #traitement fichier par fichier


#traitement du nom d'entree et du nom de sortie
$filename=$files[$nfile];
if ($input ne "") { # traitement du nom d'entree
    $tmp=$filename;
    if ($output=~/\//) {
	$tmp =~ s/.*\///;
    }
    if ($input=~/\.[^\/]$/) {
	$tmp =~ s/\.[^\.]*$//;
    }
    $filename=$input;
    $filename=~s/\%s/$tmp/g;
}
$msg="reading from $filename";
$msg=~s/ \-$/ input/;

if ($output ne "") { # traitement du nom de sortie
    $tmp="";
    if ($batchfile ne "") {
	$tmp=$ofilename{$filename};
	if ($tmp eq "") {
	    $ifile=$filename;
	    $ifile=~s/.*\///;
	    $tmp=$ofilename{$ifile};
	    if ($tmp eq "") {
		$ifile =~ s/\.[^\.]*$//;
		$tmp=$ofilename{$ifile};
	    }
	}
    }
    if ($tmp eq "") {
	$tmp=$filename;
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
} else { # traitement par defeaut du nom de sortie
    $ofile="-";
}
&verbose("$msg");
$nfile++;
open(FILE, "<$filename") || die $!; # ouverture du fichier d'entree
if (($ocmd ne "") && ($ofile eq "-")) {
  open(OFILE, "$ocmd") || die $!; # ouverture du fichier de sortie
} else {
    if ($output =~ /%s/) {
	open(OFILE, "$ocmd>$ofile") || die $!; # ouverture du fichier de sortie
    } else {
	open(OFILE, "$ocmd>>$ofile") || die $!; # ouverture du fichier unique de sortie en mode append
    }
}

#parametres d'initialisation du fichier
$turn_end=0;
&initcontent(); # initialisation de la variable $content
@begin_matching=();
$end_matching=0;
$next_matching=0;
$prev_matching=0;
$speechduration=0;
@overlappingevent=();
$overlappingbackground="";
if ($keepaudiofilename) { # on garde le nom du fichier qui est specifie dans le .trs
    $filename="";
} else { # on garde le nom du fichier d'entree
    $filename=~s/^.*\///; # remove directory from file
    $filename=~s/\.[^\.]+$//;  # remove extent. from file
}
%name=%scope=%dialect=%speaker=%topic=%accent=%genre=();
#------------- fin de l 'initialisation des parametres pour le fichier



$file_content=join("",<FILE>);

if ($outputformat =~ /^stm(\-ne)?$/i || $outputformat eq "lex") {
    #unclean preprocessing of "pronounce tags" 
    # remplacement des balises next et previous, un peu difficile � traiter autrement 
    while ($file_content=~s/<event\s+([^>]*extent=\"next\"[^>]*\/>\s*\n\s*[^<\s]\S+)(.*?\n)/@@@\@$2/si ) {
	$attributes=$1."\n";
#	print "$1 -- $2";
#	exit;
	my $replace="";
	if ($attributes=~s/^([^>]*)\/>//) {
	    my $tmp=$1;
	    $tmp=~s/\"next\"/\"begin\"/;
	    $replace="<Event ".$tmp."/>".$attributes;
	    $tmp=~s/\"begin\"/\"end\"/;
	    $replace.="<Event $tmp/>\n";
	}
	($file_content=~s/@@@@/$replace/si);
    }
    #supprime les balises next restant (suivies d'une autre balise event = balise non conventionnelle
#    while ($file_content=~s/(<event\s+[^>]*extent=\"next\"[^>]*\/>)\s*\n//si) {
#	&verbose("warning : skipping ambiguous tag in $filename : $1");
#    }
    #balise previous, patch version 0.74
   while ($file_content=~s/\n(\s*[^<][^\n]*\n<event\s+[^>]*extent=\"previous\"[^>]*\/>)/\n@@@@/si) {
 	$attributes=$1;
 	my $replace="";
 	if ($attributes=~s/(\S+)\s*\n\s*<event([^>]*?)\/>$//si) {
	    my $word=$1;
	    my $tmp=$2;
           $tmp=~s/\"previous\"/\"end\"/;
	    $replace=$word."\n<Event ".$tmp."/>\n";
	    $tmp=~s/\"end\"/\"begin\"/;
	    $replace=$attributes."\n<Event $tmp/>\n".$replace;
	}
	($file_content=~s/@@@@/$replace/si);
    }
    #supprime les balises previous restant (pr�c�d�es d'une autre balise event = balise non conventionnelle
#    $file_content=~s/<event\s+[^>]*extent=\"previous\"[^>]*\/>\s*\n//sig;
    @pron=();
    $id=0;
    while ($file_content=~s/<event\s+([^>]*desc=\"1[1-9] cent...\"[^>]*)\/>/@\@$id@@/si) { push (@pron,$1);$id++; };
    $id=0;
    foreach $attributes (@pron) {
	if ($attributes =~ /extent=\"previous\"/) {
	    ($file_content=~s/1([1-9])00\s*@\@$id@@/1$1 cents/si) || ($file_content=~s/1([1-9])(..)\s*@\@$id@@/1$1 cent $2/si);
	}
	if ($attributes =~ /extent=\"begin\"/) {
	    $id1=$id+1;
	    ($file_content=~s/@\@$id@@\s*1([1-9])00\s*@\@$id1@@/1$1 cents/si) || ($file_content=~s/@\@$id@@\s*1([1-9])(..)\s*@\@$id1@@/1$1 cent $2/si);
	}
	$id++;
    }
    @pron=();
    $id=0;
    while ($file_content=~s/<event\s+([^>]*desc=\"\([^\)]*:\)[^>]*)\/>/@\@$id@@/si) { push (@pron,$1);$id++ };
    $id=0;
    foreach $attributes (@pron) {
	my $url="";
	($attributes=~/\([^\)]*:\)\s*([^\"]*)/) && ($url=$1);
	if ($attributes =~ /extent=\"previous\"/) {
	    ($file_content=~s/\S+\s*@\@$id@@/$url/si);
	}
	if ($attributes =~ /extent=\"begin\"/) {
	    $id1=$id+1;
	    ($file_content=~s/@\@$id@@\s*\S+\s*@\@$id1@@/$url/si);
	}
	$id++;
    }

}
@lines=split(/\n/,$file_content);
LINE:
map { # traitement ligne a ligne du fichier d'entree
    chomp;
    if (/<\?xml/i) { # detection de l'encoding du fichier d'entree
	if (/encoding=\"(.*?)\"/i) {
	    $encoding=$1;
	}	
    }
    
    elsif (/<Trans/ && $proceed{trans} ) { # traitement de la balise Trans
	if ($keepaudiofilename && /.*audio_filename=\"(.*?)\"/) {
	    $filename=$1;
	}
	if (/scribe=\"(.*?)\"/) {
	    $scribe=$1;
	}
	if (/version=\"(.*?)\"/) {
	    $trans_version=$1;
	}
	if (/version_date=\"(.*?)\"/) {
	    $trans_versiondate=$1;
	}
	if (/xml:lang=\"(.*?)\"/) {
	    $trans_lang=$1;
	}
	if (/elapsed_time=\"(.*?)\"/) {
	    $elapsed_time=$1;
	}
    }
     
    elsif (/<Speaker / && $proceed{speaker}) { # traitement de d'une balise Speaker (header du fichier d'input .trs)
	if (/id=\"(.*?)\"/) { $id=$1; $speaker{$id}="set"; }
	if (/dialect=\"(.*?)\"/) { $dialect{$id}=$1;  }
	if (/accent=\"(.*?)\"/) { $accent{$id}=$1;}
	if (/type=\"(.*?)\"/) { $genre{$id}=$1;} else {$genre{$id}="unknown";}
	if (/check=\"(.*?)\"/) { $check{$id}=$1;}
	if (/scope=\"(.*?)\"/) { $scope{$id}=$1;} else {$scope{$id}="";}
	if (/name=\"(.*?)\"/) { 
	    $tmp_name=$1;
	    if ($scope{$id} ne "global") {
		$name{$id}=$format{unchecked_speaker};
		$name{$id}=~s/%filename/$filename/;
		$name{$id}=~s/%speakername/$tmp_name/;
	    } else {
		$name{$id}=$tmp_name;
	    }
	    if ($norm{speaker}==1) {
	      $name{$id}=~s/[\s\#\(\)\+\-\/,\']+\s*/_/g;
	      $name{$id}=~s/\&.*?\;//g;
	      $name{$id}=~s/_+$//g;
	    } elsif ($norm{speaker}==2) {
	      $name{$id}=~s/\s+/_/g;
	      $name{$id}=~s/\,.*//g;
	    }
	}
#	if ($genre{$id} eq "") 
    }
 
    elsif (/<Topic / && $proceed{topic} ) { # traitement d'une balise Topic (header du fichier d'input .trs)
	/id=\"([^\"]*)\"/;
	$id=$1;
	/desc=\"([^\"]*)\"/;
	$desc=$1;
	$topic_desc{$id}=$desc;
    }
       
    elsif (/<Episode/ && $proceed{episode} ) { # traitement de la balise Episode
	%speech_start=%speech_time=%speech_transcription=%active=%new_active=();  $speakers_segments="";$sections="";
	if (/program=\"(.*?)\"/) {
	    $program=$1;
	}
	if (/air_date=\"(.*?)\"/) {
	    $air_date=$1;
	}
	&printheader();
    }
    
    elsif (/<Section / && $proceed{section}) { # traitement d'une balise Section
	$section_topic="";
	$section_topicid="";
	$section_type="";
	if (/type=\"([^\"]*)\"/) { 
	    $section_type=$1;
	    if ($section_type eq "nontrans") {
		$section_topic.="$format{nospeaker_topic} ";
		$speaker_turn=$format{notrans_speaker};
	    }
	}
	if (/topic=\"([^\"]*)\"/) {
	    $section_topicid=$1;
	    $section_topic=$topic_desc{$1};
	}
	if (/startTime=\"([0-9\.]+)\"/) {
	    $section_begin=$1;
	}
	if (/endTime=\"([0-9\.]+)\"/ ) { 
	    $section_end=$1;	
	}

    }

    elsif (/<Turn / && $proceed{turn} ) { # traitement d'une balise Turn (tour de parole)
	$sync_type="turn";
	$changedbackground=0;
	$overlappingspeakers=0;
	if ($conditions_next_turn ne "") {
	    @conditions_turn=@conditions_next_turn;
	    $condition_next_turn="";
	} else {
	    @conditions_turn=(0); #condition f0
	}
	$channel_turn="";
	$mode_turn="";
	$fidelity_turn="";
	if (/endTime=\"([0-9\.]+)\"/ ) { 
	    $turn_end=$1;	
	}
	if (/startTime=\"([0-9\.]+)\"/) {
	    $turn_begin=$1;
	    $syncstart=$turn_begin;
	}
        if (/channel=\"([^\"]*)\"/) {
	    $channel_turn=$1;
	    if ($channel_turn eq "telephone") {
		push(@conditions_turn,2); #condition f2
	    }
	}
	if (/fidelity=\"([^\"]*)\"/) {
	    $fidelity_turn=$1;
	    if ($fidelity_turn eq "low") {
		push(@conditions_turn,4); #condition f4
	    }
	}
        if (/mode=\"([^\"]*)\"/) {
	    $mode_turn=$1;
	    if ($mode_turn eq "spontaneous") {
		push(@conditions_turn,1); # condition f1
	    }
	}
	if ((!/speaker/) || /speaker=\"\"/) {
#	    print "ici $_\n";
	    $speakerid="";
	    if ($section_type eq "nontrans") {
		$speaker_turn=$format{notrans_speaker};
		$content{$active_speaker_id}=$format{notrans_transcription};
	    } else {
		$speaker_turn="no_speaker";
	    }
	}
	else {
#	    print "l� $_\n";
	    /speaker=\"([^\"]+)\"/;
	    $speaker_turn=$1;
	    $speakerid=$1;
	    if (!defined($name{$speakerid})) {
		#if no speakername for speakerid, there shall be an overlapping speaker condition
		$overlappingspeakers=1;
	    } else {
		$active_speaker_id=$speakerid;
	    }
	    if ($dialect{$speaker_turn} eq "nonnative") {
		push(@conditions_turn,5); # condition f5
	    }
	}
    }
   
 #-------------------- balises interne au tour de parole
       
    elsif (/<Sync time=\"([0-9\.]+)\"\/>/ && $proceed{sync}) { # traitement d'une balise de Sync (tour de parole)
	$syncend=$1;
	if (($turn_end>$syncend)&&($syncend>$turn_begin)) {
	    &flush_sync($syncstart,$syncend);
	    $sync_type="sync";
	}
	$changedbackground=0;
	$syncstart=$syncend;
    }
    
    elsif (/<Background/ && $proceed{background}) { # traitement d'une balise de Background (fond sonore)
	/time=\"([0-9\.]+)\"/;
	$syncend_tmp=$1;
	if (($turn_end>=$syncend_tmp)&&($syncend_tmp>$turn_begin)) {
	    # un background a le droit d'etre en fin de tour
	    $syncend=$syncend_tmp;
	    &flush_sync($syncstart,$syncend);
	} else { # cas d'une balise background "off" en debut de tour
	    if ($overlappingbackground=~/off/ && $turn_begin==$syncend_tmp) {
		$overlappingbackground="";
	    }
	}
	if (/level=\"([^\"]*)\"/) {
	    $bg_level=$1;
	    if ($bg_level eq "off") {
		$overlappingbackground.=".off";
	    }
	}
	if (/type=\"([^\"]*)\"/) {
	    $bg_type=$1;
	    if ($bg_level ne "off") {
		$overlappingbackground=$1;
	    }
	}
	$changedbackground=1;
	$sync_type="background";
	$syncstart=$syncend;
    }
   
    elsif (/<Who / && $proceed{who} ) { # traitement d'une balise Who (locuteurs superposes)
	if (/nb=\"([^\"]*)\"/) {
	    $who_nb=$1;
	    $active_speaker_id=(split(/\s+/,$speakerid)) [$who_nb-1];
#	    $content.=&format("who");
	}
    }
        
    elsif (/<Comment/i && $proceed{comment} ) { # traitement d'une balise Comment
	if (/desc=\"([^\"]*)\"/i) { 
	    $comment_desc = $1;
	    &flush_comment();
	}
    }
    
    elsif (/<(Event).*desc=\"([^\"]*)\"/i && $proceed{event} ) { # traitement d'une balise Event
	$event_desc = $2;
	$event_desc =~s/\s+/_/g;
#	$event_type=$1;
	$event_duration="";
	if (/type=\"([^\"]*)\"/) {
	    $event_type=$1;
	} else {
	    $event_type="";
#	  $event_type="noise"; #cas limite ou pas de type dans un event
	}
	$event_type=~s/\s+/_/g;
	if (/extent=\"([^\"]*)\"/) {
	    $event_duration=$1;
	}
	if ($event_duration eq "next") {
	    &warning("in file $filename - skipping ambiguous next tag between $begin and $end");
	    goto ENDLINE;
	}
	if ($ignore||$extract) {
	    $tmp="${event_type}:$event_desc";
	    @matching_patterns=grep { $tmp =~ /$_/i } @patterns;
	    @matching_patterns_content=grep { $ign_content{$_} } @matching_patterns;
	    @matching_patterns_segment=grep { $ign_segment{$_} } @matching_patterns;
	    @matching_patterns_extract=grep { $ext_tag{$_} } @matching_patterns;

	    if ($#matching_patterns>=0) {
#		$something_was_removed=1;
		if ($event_duration eq "begin"  ) {
		    if ( $#matching_patterns_content>=0 || $#matching_patterns_segment>=0 || $#matching_patterns_extract>=0 ) {
			push(@begin_matching,$tmp);
		    } else {
			$instant_matching=1;
		    }
		} else {
		    if ($event_duration eq "end" ) {
			if ( $#matching_patterns_content>=0 || $#matching_patterns_segment>=0 || $#matching_patterns_extract>=0  ) {
			    push(@end_matching,$tmp);
			    if (grep { $_ eq $tmp } @begin_matching) {
				@begin_matching=grep { $_ ne $tmp } @begin_matching;
				$end_matching=1;
			    }
			    else {
				&verbose("unmatched end $tmp");
			    }
			}  else {
			    $instant_matching=1;
			}
		    } else {
			if ($event_duration eq "next" ) {
			    if (  $#matching_patterns_content>=0 ) {
				$next_matching=1;
			    }  else {
				$instant_matching=1;
			    }
			} else {
			    if ($event_duration eq "previous") {
				if ( $#matching_patterns_content>=0 ) {
				    $prev_matching=1;
				}  else {
				    $instant_matching=1;
				}
			    } else {
				$instant_matching=1;
				if ($event_duration eq "instantaneous") {
				    if ( $#matching_patterns_segment>=0 ) {
					$removeline=1;
				    }
				}
			    }
			}
		    }
		}
	    }
	}

	if ($ignore && $prev_matching) {
	    #removes previous word or event (!!may not be compatible with annotation convention)
	    $content{$active_speaker_id}=~s/\s*\S+\s*$/ /;
	    $content{$active_speaker_id}=~s/^\s+$//;
	    $ignoring_flag =~ s/previous//g;
	} 

	if ($extract && $prev_matching) {
	    $content{$active_speaker_id}.=$lastword;
	    $lastword="";
	}

	if ($event_duration ne "" ) {
	    if ($event_duration eq "begin") { push (@overlappingevent,"$event_desc:$event_type"); $event_extent="begin";}#$event_desc.="-";}
	    if ($event_duration eq "end") { @overlappingevent=grep {$_ ne "$event_desc:$event_type"} @overlappingevent; $event_extent="end";}# $event_desc="-$event_desc";}
	    if ($event_duration eq "previous") { 
		$event_desc="$event_desc";
	    }
	    if ($event_duration eq "next") { $event_desc="${event_desc}";push(@pendingevent,"${event_desc}:$event_type");}
	}


	if ($printevent) {
	    &printevent();
	}


	$end_matching=$instant_matching=$prev_matching=0;

	if ($ignore) {
	    $ignoring_flag=~ s/instantaneous//g;
	    foreach $pattern (@patterns) {
		$flag{$pattern} =~ s/instantaneous//g;
	    }
	}

	
    }
        
    elsif (! /^\s*</ && $proceed{transcription} ) { # traitement du contenu de la transcription (#PCDATA)
	chomp;
	while(s/^\s//){};while(s/\s$//){};
	if (/(\S+)\s*$/) {$lastword=$1;$speech="yes";} else { goto ENDLINE;}
	if ($ignore) {
	    if ($next_matching) {
		$_=~s/\s*\S+\s*//;
		$next_matching=0;
	    }
	    if ($#begin_matching>=0) {
		@removedwords=();
		@removedwords=split(/\s+/,$_);
		if ($#removedwords >= 1) {  # si balises ignore sur plusieurs mots dans un segment, alors retire la ligne (si $ign_segment{$pattern})
		    &warning("removed segment ($filename-$syncstart) : $content{$active_speaker_id} $_ ");
		    $_="";
		    $removeline=1;
		}
	    }
	} else {
	    if ($extract) {
		if ($next_matching) {
		    if (/\s*(\S+)\s*/) {
			$_=$1;
			$next_matching=0;
		    }
		}
		if ($#begin_matching<0) {
		    $_="";
		}
	    } 

	}
	
	

	if ($#pendingevent>=0) {
	    $toprint_event_begin="";
	    $toprint_event_end="";
	    foreach $full_event (@pendingevent) {
		($event_desc,$event_type)=split(/:/,$full_event,2);
		$toprint_event_begin=&format(event_begin);
		$toprint_event_end=&format(event_end);
		s/(\s*)$lastword_protected(\s*.*?)$/$1$format{separator}$toprint_event_begin$format{separator}$lastword$format{separator}$toprint_event_end$fomat{separator}$2/s;
		if ($lastword_protected eq "") {
		    &warning("in file $filename - removing ambiguous previous tag between $begin and $end");
		}
	    }
	    @pendingevent=();
#	    $_=~s/^(\s*)(\S+)(\s*)/$1$format{separator}$toprint_event_begin$format{separator}$2$format{separator}$toprint_event_end$format{separator}$3/;
	}

	$content{$active_speaker_id}.=$_.$format{separator};
	
#	if ($cut) {
#	    $content=~s/\s*$//;
#	    if ($content ne "") {
#		$content.="\n";
#	    }
#	}
    }
    
 
    
    #----------------- fin des balises et contenu du tour de parole   
     elsif (/<\/Turn/) { # traitement d'une fin de Turn
	&flush_speakers($turn_begin,$turn_end);
	&flush_turn($syncstart,$turn_end);
    }
  
    elsif (/<\/Section>/) { # traitement d'une fin de Section
	&flush_section();
    }    
    
    elsif (/<\/Episode>/) { # traitement d'une fin de Section
	$speakerid="";
	&flush_speakers();
	&flush_episode();
    }  
    
  ENDLINE:
    1;
    
    
} @lines;


if ($proceed{transcription}) {
    &verbose("SPEECH_DURATION: $filename $speechduration");
}

$totalspeechduration+=$speechduration;
close(FILE);
close(OFILE);
}

if ($proceed{transcription}) {
    &verbose("SPEECH_DURATION: TOTAL $totalspeechduration");
}
$endtime=time();
 $difftime=$endtime-$inittime;
    if ($difftime!=0) {
	&verbose(sprintf("$difftime seconds to process $nfiles files (%.2f f/s)",$nfiles/$difftime));
    }
    else {
	&verbose("less than 1 second to process $nfiles files\n");
    }


exit(0);

#-------------fin de du traitement

#procedures de formattage de la sortie
sub flush_speakers() {
    ($begin,$end)=@_;
    %new_active=();
#    print "$speakerid\n";
    foreach $active_speaker_id (split(/\s+/,$speakerid)) {
#	print "-> $begin $end $speakerid $name{$active_speaker_id} \n";
	if ($active{$active_speaker_id} != 1) {
	    $active{$active_speaker_id}=1;
	    $speech_time{$active_speaker_id}=0;
	    $speech_start{$active_speaker_id}=$begin;
	    $speech_transcription{$active_speaker_id}="";
	}
	$new_active{$active_speaker_id}=1;
    }
    foreach $active_speaker_id (keys %active) {
	if ($active{$active_speaker_id}==1) {
	    if ($new_active{$active_speaker_id}==1) {
		$speech_time{$active_speaker_id}+=$end-$begin;
		$speech_transcription{$active_speaker_id}.=$content{$active_speaker_id};
	    } else {
		$speech_time{$active_speaker_id}=sprintf($format{num},$speech_time{$active_speaker_id});
		$speech_start{$active_speaker_id}=sprintf($format{num},$speech_start{$active_speaker_id});

		$speakers_segments.=&format("speaker_segment");
#		print "<-".&format("speaker_segment")."$name{$active_speaker_id} $begin $end $speech_time{$active_speaker_id} $speech_start{$active_speaker_id}\n";
		$active{$active_speaker_id}=0;
		$speech_time{$active_speaker_id}=0;
		$speech_start{$active_speaker_id}=-1;
		$speech_transcription{$active_speaker_id}="";
	    }
	}
	$new_active{$active_speaker_id}=0;
    }
    
}


sub flush_sync() { # procedure de rajout d'un segment dans $syncs
	($begin,$end)=@_;
	$transcription="";
	$whos="";
	$duration=$end-$begin;
	foreach $active_speaker_id (split(/\s+/,$speakerid)) {
	    if ($cut) {
		$content{$active_speaker_id}=~s/\n/\<lr\>/gms;
	    }
	}
	if ($speech eq "yes") {
	    $speechduration+=$end-$begin;
	}
	#analyse des conditions acoustiques
	&acoustic_conditions();
	#normalisation de la transcription
	&norm_trans();
	#normalisation du topic de la section
	$section_topic=~s/\s+/_/g;
	#mise en forme
	if ($begin>$end) { # probleme de synchro dans le fichier trs (lie a un bug de transcriber)
	     &warning("sync problem in $filename ($filename near $begin or $end) - a transcribed segment may miss");
	} else {
		$begin=sprintf($format{num},$begin);
		$end=sprintf($format{num},$end);
		$duration=sprintf($format{num},$duration);
		if ($overlappingspeakers) {
		    $who_nb=1;
		    foreach $active_speaker_id (split(/\s+/,$speakerid)) {
			$whos.=&format("who");
			$who_nb++;
		    }
		} else {
		    $transcription=$content{$active_speaker_id}; # transcription utile uniquement si pas overlappingspeakers
		    if ($transcription=~/\S+/) {
			$speech="yes";
		    } else {
			$speech="no";
		    }
		}
		$toprint=&format("sync");
		if ($speech eq "no" && $speaker_turn ne "no_speaker") {
#		    print $toprint." $speakerid $speaker_turn ".&format(speakername)." <".&format(speaker,1)." >".&format(transcription)."\n";
		}
		if ($toprint ne "") {
		    $syncs.=$toprint;
		}
	}
	&initcontent();
}

sub flush_section() { # procedure de rajout d'une section dans $sections
    $section_toprint=&format("section");
    $sections.=$section_toprint;
    $turns="";
}

sub flush_episode() { # procedure d'impression de l'�pisode dans le fichier de sortie
    print OFILE &format("episode");
}

sub flush_turn() { # procedure de rajout d'un tour de parole dans $turns
    ($begin,$end,$transcription)=@_;
    &flush_sync($begin,$end);
    $turn_toprint=&format("turn");
    $sync_type="turn";
    $turns.=$turn_toprint;
    $syncs="";
    $changedbackground=0;
    $speaker_turn="";
}

sub printsectionheader { # impression de l'en-tete des section dans le fichier de sortie
    
}

sub printheader { # impression de l'en-tete du fichier de sortie
    $header="";
    if ($outputformat eq "stm") {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year+=1900;
	$mon++;
	$conv_date=sprintf("%02d:%02d:%02d %04d/%02d/%02d",$hour,$min,$sec,$year,$mon,$mday);
	
	$header=&format("header");
    } elsif ($outputformat eq "trs") {
	$topics="";
	foreach $topicid (sort bynum keys %topic_desc) {
#	    $topicdesc=$topic_desc{$topicid};
	    $topics.=&format("topic")."\n"; 
	}
	$speakers="";
	foreach $speakerid (sort bynum keys %speaker) {
	    $speakers.=&format("speaker_inheader")."\n";
	}


	$header=&format("header");
    }
    if ($header ne "") {
	print OFILE $header;
    }
}

sub flush_comment() { # procedure de rajout d'un comment dans $content{$active_speaker_id}
    if ($printevent) {
	$content{$active_speaker_id}.=&format(comment).$format{separator};
#	print 	$content{$active_speaker_id};
#	print "\n";
    }
}

sub printevent() { # procedure de rajout d'un event dans $content
#in : event_type event
#out : content
#sub : flush_event


    if ($ignore) {
	if (! ($next_matching||$prev_matching||$instant_matching||($#begin_matching>=0)||$end_matching)) {
	    &flush_event();
	}
    } else { 
	if ($extract) {
	    if ($next_matching||$prev_matching||$instant_matching||($#begin_matching>=0)||$end_matching) { 
		    &flush_event();
	    }
	} else {
	    &flush_event();
	}
    }
}

sub flush_event() { # procedure utilisee par printevent pour ajouter un event dans $content
#in : event_type event event_duration content
#out : content

    if ($event_duration ne "next") {
	if ($event_duration eq "previous") {
	    $toprint_event_begin=&format(event_begin);
	    $toprint_event_end=&format(event_end);
	    $lastword_protected=&protect($lastword);
# mode event : on tag le dernier mot et non le dernier event
	    $content{$active_speaker_id}=~s/(\s*)$lastword_protected(\s*.*?)$/(($1 eq "")?"":$1.$format{separator}).$toprint_event_begin.$format{separator}.$lastword.$format{separator}.$toprint_event_end.$format{separator}.$2/es;

	    # mode retenu, compatible avec transcriber : on retient le dernier event ...
#	    $content=~s/(\s*)(\S+)(\s*)$/$1$format{separator}$toprint_event_begin$format{separator}$2$format{separator}$toprint_event_end$format{separator}$3/s;
	  }
	else {
	    if ($event_duration eq "begin") {
		$toprint_event=&format("event_begin");
	    } elsif ($event_duration eq "end") {
		$toprint_event=&format("event_end");
	    } else {
		$toprint_event=&format("event");
	    }
	    $content{$active_speaker_id}.=$toprint_event.$format{separator};
	}
    }
}

sub format { # procedure de formatage d'une chaine de caracteres en fonction des variables de parsing du fichier trs
    ($string,$printable)=@_;
    return "" unless $string ne "";
    if ($printable) {
      print "analyse de : $string - \n";
    }

    if (($event_type eq "") && defined($format{"noeventtype_$string"})) {
        if ($printable) {
	  print "cas noeventtype : $string ".$format{"noeventtype_$string"}."\n";
	}
	return &format($format{"noeventtype_$string"},$printable);
    } elsif (($sync_type eq "turn") && defined($format{"turn_$string"})) {
        if ($printable) {
	  print "cas turn : $string ".$format{"turn_$string"}."\n";
	}
	return &format($format{"turn_$string"},$printable);
    } elsif (($sync_type eq "background") && defined($format{"background_$string"})) {
         if ($printable) {
	  print "cas background : $string ".$format{"background_$string"}."\n";
	}
	return &format($format{"background_$string"},$printable);
    } elsif (($begin eq $end) && defined($format{"null_$string"})) {
        if ($printable) {
	  print "cas null : $string ".$format{"null_$string"}."\n";
	}
	return &format($format{"null_$string"},$printable);
    } elsif (($section_topicid eq "") && defined($format{"notopic_$string"})) {
        if ($printable) {
	  print "cas notopic : $string ".$format{"notopic_$string"}."\n";
	}
	return &format($format{"notopic_$string"},$printable);
      } elsif (($overlappingspeakers==1) && defined($format{"overlappingspeakers_$string"})) {
        if ($printable) {
	  print "cas overlapping : $string ".$format{"overlapping_$string"}."\n";
	}
	return &format($format{"overlappingspeakers_$string"},$printable);
    } elsif ((($section_type eq "nontrans") || $removeline&&$ignore) && defined($format{"notrans_$string"}) ) {
	if ($printable) {
	    print "cas notrans $string ".$format{"notrans_$string"};
	}
	return &format($format{"notrans_$string"});
    } elsif (($speech eq "no") && (defined($format{"nospeech_$string"})) )  {
	if ($printable) {
	    print "cas speech : $string ".$format{"nospeech_$string"};
	}
	return &format($format{"nospeech_$string"},$printable);
    } elsif (($speaker_turn eq "no_speaker") && defined($format{"nospeaker_$string"}) ) {
	if ($printable) {
	    print "cas nospeaker : $string -> ".$format{"nospeaker_$string"};
	}
	return &format($format{"nospeaker_$string"},$printable);
    } elsif (defined($format{$string})) {
      if ($printable) {
	print "cas format{$string}=".$format{$string}."\n";
      }
	return &format($format{$string},$printable);
    } elsif ($string=~/%/s) {
      if ($printable) {
	print "cas % : $string ";
      }
      $string=~s/%(\w+)\{%(\w+)}/$$1{$$2}/egs;
      $string=~s/%(\w+)/&format($1,$printable)/egs;
      $string=~s/%\{(\w+)\}/&format($1,$printable)/egs;
      if ($printable) {
	print " $string \n";
      }
      return "$string";
    } elsif ($string =~ /^\w+$/ && defined($$string)) {
      if ($printable) {
	print "cas \$ : $string $$string\n";
      }
      return $$string;
    } else {
      if ($printable) {
	print "cas limite : $string $string\n";
      }
	return $string;
      return "";
    }
}

sub initformat() { # initialisation du format des fichiers de sortie
    if ($outputformat=~/%/) {
        $outputformat=~s/\\n/\n/g;
	$outputformat=~s/\\t/\t/g;
	$format{sync}=$outputformat;
	$format{nospeaker_speakername}="noname";
    }

    if ($outputformat =~  /^stm(\-ne)?$/i ) {
	$proceed{comment}=0;
	$format{header}=';; Transcriber conversion by parsetrs v%version on %conv_date with encoding %encoding
;; program %program of %air_date
;; transcribed by %scribe, version %trans_version of %trans_versiondate
;;
;; CATEGORY "0" "" ""
;; LABEL "O" "Overall" "Overall"
;;
;; CATEGORY "1" "Hub4 Focus Conditions" ""
;; LABEL "F0" "Baseline//Broadcast//Speech" ""
;; LABEL "F1" "Spontaneous//Broadcast//Speech" ""
;; LABEL "F2" "Speech Over//Telephone//Channels" ""
;; LABEL "F3" "Speech in the//Presence of//Background Music" ""
;; LABEL "F4" "Speech Under//Degraded//Acoustic Conditions" ""
;; LABEL "F5" "Speech from//Non-Native//Speakers" ""
;; LABEL "FX" "All other speech" ""
;; CATEGORY "2" "Speaker Sex" ""
;; LABEL "female" "Female" ""
;; LABEL "male"   "Male" ""
;; LABEL "unknown"   "Unknown" ""
';

	$norm{speaker}=1;
	$format{num}="%.3f";
	$format{who}="/%speakername: ";
	undef($format{noeventtype_event});
	undef($format{noeventtype_event_begin});
	undef($format{noeventtype_event_end});

	$format{sync}="%filename 1 %speaker %begin %end <o,%conditions,%speakergenre> %transcription\n";
	$format{null_sync}="";
	$format{nospeaker_transcription}="";
	$format{overlappingspeakers_transcription}="ignore_time_segment_in_scoring";
	$format{overlappingspeakers_speaker}="excluded_region";
	$format{overlappingspeakers_speakergenre}="unknown";
	$format{overlappingspeakers_conditions}="";
	$format{speaker}="%speakername";
	$format{nospeaker_speakername}="inter_segment_gap";
	$format{event}="[%event_desc]";
	$format{event_begin}="[%event_desc-]";
	$format{event_end}="[-%event_desc]";
	$format{nospeech_speaker}="inter_segment_gap";
	$format{nospeech_transcription}="";
	$format{nospeech_speakergenre}="";
	$format{notrans_speaker}="excluded_region";
	$format{notrans_conditions}="";
	$format{notrans_speakergenre}="unknown";
	$format{notrans_transcription}="ignore_time_segment_in_scoring";
	$printevent=1;
	if ($ignoresegment eq "") {
	  $ignoresegment.="nontrans,language";
	}
	if ($ignoretag eq "" && ($outputformat=~/^stm$/)) {
	  $ignoretag="event:,lexical,pronounce:(?!pi),entities:,language:,comment:";
	}

	if ($outputformat=~/^stm\-ne$/i) {
	  $ignoretag="^(?!entities).*:,noise:,event:,lexical,pronounce:(?!pi),language:,comment:";
#	    $ignoretag=";
	    $format{event_begin}="[%event_desc";
	    $format{event}="[%event_desc]";
	    $format{event_end}="]";

	}
    }


    if ($outputformat =~ /^trs$/i)  {
	$cut=1;
	$format{header}='<?xml version="1.0" encoding="%encoding"?>
<!DOCTYPE Trans SYSTEM "trans-13.dtd">
<Trans scribe="%scribe" audio_filename="%filename" version="%trans_version" version_date="%trans_versiondate" xml:lang="%trans_lang" elapsed_time="%elapsed_time">
<Topics>
%topics</Topics>
<Speakers>
%speakers</Speakers>
';
	$format{episode}='<Episode program="%program" air_date="%air_date">
%sections</Episode>
</Trans>
';
	$format{section}='<Section type="%section_type" topic="%section_topicid" startTime="%section_begin" endTime="%section_end">
%turns</Section>
';
	$format{turn}='<Turn speaker="%speakerid" startTime="%turn_begin" endTime="%turn_end" mode="%mode_turn" fidelity="%fidelity_turn" channel="%channel_turn">
<Sync time="%turn_begin"/>
%syncs</Turn>
';

	$format{separator}="\n";
	$format{topic}='<Topic id="%topicid" desc="%topicdesc"/>';
	$format{speaker_inheader}='<Speaker id="%speakerid" name="%speakername" check="%speakercheck" type="%speakergenre" dialect="%speakerdialect" accent="%speakeraccent" scope="%speakerscope"/>';

	undef($format{nospeaker_transcription});
	undef($format{notrans_transcription});
	undef($format{notrans_speaker});
	$format{overlappingspeakers_transcription}='%whos
';
	$format{who}='<Who nb="%who_nb"/>
%content{%active_speaker_id}';
	$format{unchecked_speaker}="%speakername";
	$format{num}="%s";
#	$format{notopic_section}='<Section type="%section_type" startTime="%section_begin" endTime="%section_end">
#%turns</Section>
#';
	$format{speaker}='speaker="%speakerid" ';
	$format{nospeaker_speaker}="";
	$format{nospeech_speaker}="";
	undef($format{nospeaker_transcription});
	undef($format{nospeech_transcription});

	$format{nospeaker_turn}='<Turn startTime="%turn_begin" endTime="%turn_end" channel="%channel_turn">
<Sync time="%turn_begin"/>
%syncs</Turn>
';
	$format{sync}='<Sync time="%begin"/>
%transcription';
	$format{turn_sync}='%transcription';
	$format{background_sync}='<Background time="%begin" type="%bg_type" level="%bg_level"/>
%transcription';
	$format{event}='<Event desc="%event_desc" type="%event_type" extent="instantaneous"/>';
	$format{event_begin}='<Event desc="%event_desc" type="%event_type" extent="begin"/>';
	$format{event_end}='<Event desc="%event_desc" type="%event_type" extent="end"/>';
	$format{noeventtype_event}='<Event desc="%event_desc" extent="instantaneous"/>';
	$format{noeventtype_event_begin}='<Event desc="%event_desc" extent="begin"/>';
	$format{noeventtype_event_end}='<Event desc="%event_desc" extent="end"/>';
	$format{comment}='<Comment desc="%comment_desc"/>';


	$printevent=1;
	
    }
    if ($outputformat =~ /^lexh?$/i ) {
	$proceed{comment}=0;
	$printevent=1;
	$format{sync}="%transcription (%filename-%begin-%end)\n";
	$ignoretag='noise:(?!i$),lexical,pronounce:(?!pi),entities:,language:,comment:';
	$format{event_begin}="";
	$format{event_end}="";
	$format{event}='[%event_desc]';
	$format{num}="%08.3f";
	$format{nospeech_transcription}="";
    }

    if ($outputformat =~ /^mdtm$/i ) {
	$proceed{who}=$proceed{sync}=$proceed{transcription}=$proceed{comment}=$proceed{event}=0;
	$format{speaker_segment}="%filename 1 %speech_start{%active_speaker_id} %speech_time{%active_speaker_id} speaker NA %genre{%active_speaker_id} %name{%active_speaker_id}\n";# %speech_transcription{%active_speaker_id}\n";
	$format{num}="%0.3f";
	$norm{speaker}=2;
	$format{episode}="%speakers_segments";
#	$ocmd=' | gawk \'BEGIN{spk=""} {if ($NF==spk) {spkdur+=$4;} else {if (spk!="") {print $1 " " spkbegin " " spkdur " NA " spkgenre " " spk};spk=$NF;spkdur=0;spkgenr=$6;spkbegin=$3} }\'';

    }


    if ($outputformat =~ /^speech$/i ) {
	$format{sync}="(%filename-%speaker-%begin-%end)";
    }

    if ($outputformat =~ /full/i ) {
	$format{sync}="%transcription (%speaker-%conditions) (%topic) (%filename-%begin-%end)";
	$printevent=1;
    }


    if ($outputformat =~ /^te?xte?$/i ) {
	$format{sync}="%transcription\n";
	$format{nospeaker_transcription}="";
    }
    if ($outputformat =~ /null?/i ) {
	$format{sync}="";
	$format{nospeaker_transcription}="";
    }

    if ($execformat) {
      &verbose("executing format command $execformat");
      eval($execformat);
    }
}

sub xmlclean { # initialisation de la conversion des caracteres speciaux en xml
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

sub HTMLSymb { # conversion des caracteres speciaux xml

	return ( 
	"&	&amp;",
	"\"	&quot;",
	"<	&lt;",
	">	&gt;",
	"©	&copy;",
	"®	&reg;",
	"Æ	&AElig;",
	"Á	&Aacute;",
	"Â	&Acirc;",
	"À	&Agrave;",
	"Å	&Aring;",
	"Ã	&Atilde;",
	"Ä	&Auml;",
	"Ç	&Ccedil;",
	"Ð	&ETH;",
	"É	&Eacute;",
	"Ê	&Ecirc;",
	"È	&Egrave;",
	"Ë	&Euml;",
	"Í	&Iacute;",
	"Î	&Icirc;",
	"Ì	&Igrave;",
	"Ï	&Iuml;",
	"Ñ	&Ntilde;",
	"Ó	&Oacute;",
	"Ô	&Ocirc;",
	"Ò	&Ograve;",
	"Ø	&Oslash;",
	"Õ	&Otilde;",
	"Ö	&Ouml;",
	"Þ	&THORN;",
	"Ú	&Uacute;",
	"Û	&Ucirc;",
	"Ù	&Ugrave;",
	"Ü	&Uuml;",
	"Ý	&Yacute;",
	"á	&aacute;",
	"â	&acirc;",
	"æ	&aelig;",
	"à	&agrave;",
	"å	&aring;",
	"ã	&atilde;",
	"ä	&auml;",
	"ç	&ccedil;",
	"é	&eacute;",
	"ê	&ecirc;",
	"è	&egrave;",
	"ð	&eth;",
	"ë	&euml;",
	"í	&iacute;",
	"î	&icirc;",
	"ì	&igrave;",
	"ï	&iuml;",
	"ñ	&ntilde;",
	"ó	&oacute;",
	"ô	&ocirc;",
	"ò	&ograve;",
	"ø	&oslash;",
	"õ	&otilde;",
	"ö	&ouml;",
	"ß	&szlig;",
	"þ	&thorn;",
	"ú	&uacute;",
	"û	&ucirc;",
	"ù	&ugrave;",
	"ü	&uuml;",
	"ý	&yacute;",
	"ÿ	&yuml;",
	" 	&#160;",
	"¡	&#161;",
	"¢	&#162;", 
	"£	&#163;",
	"¥	&#165;",
	"Š	&#166;",
	"%	&#167;",
	"š	&#168;",
	"©	&#169;",
	"ª	&#170;",
	"«	&#171;",
	"¬	&#172;",
	"­	&#173;",
	"®	&#174;",
	"¯	&#175;",
	"°	&#176;",
	"±	&#177;",
	"²	&#178;",
	"³	&#179;",
	"Ž	&#180;",
	"µ	&#181;",
	"¶	&#182;",
	"·	&#183;",
	"ž	&#184;",
	"¹	&#185;",
	"º	&#186;",
	"»	&#187;",
	"Œ	&#188;",
	"œ	&#189;",
	"Ÿ	&#190;",
	"¿	&#191;",
	"×	&#215;",
	"Þ	&#222;",
	"÷	&#247;",
        "à      &#224;",
	"é      &#233;",
	"ê      &#234;",
	"ç      &#231;",
	"\'     &#39;",
	"\"     &#34;",
	"è      &#232;",
        "î     &#238;",
        "ô     &#244;",
	"     &#160;",
	"û    &#251;",
	"ë &#235;",
	"û &#251;",
	"ï &#239;",
	"É &#201;",
	"À &#192;",	 
"È &#200;",
"Ê &#202;",
"Î  &#206;",
"ù &#249;",
"â &#226;",
"Ï &#207;",
"oe &#156;",
"OE &#338;",
"Ë &#203;",
"Ô &#212;",
"Â &#38;Acirc",
"ö &#246;",
   "  &#150;",
   "Â &#194;",
   "A &#196;",
   "Ç &#199;",
   "Ö &#214;",
   "Ù &#217;",
   "Û &#219;",
   "Ü &#220;",
   "á &#225;",
   "ã &#227;",
   "í &#237;",
   "ñ &#241;",
   "ò &#242;",
   "ó &#243;",
   "ú &#250;",
   "ü &#252;",
   "ÿ &#255;",
   "& &#38;",
   "-  &#45;",
   "€ &#8364;",
   "\[ &#91;",
   "\]  &#93;",

)
}

sub initcontent {
    @pendingevent=();
    $removeline=0;
    $something_was_removed=0;
    %content="";
    $lastword="";
    $speech="no";
}

sub norm_trans() { # normalisation de la transcription
    foreach $active_speaker_id (split(/\s+/,$speakerid)) {
	if ($case==1) {
	    $content{$active_speaker_id}=~ tr/[a-z]/[A-Z]/;
	}
	if ($case==2) {
	    $content{$active_speaker_id}=~ tr/[A-Z]/[a-z]/;
	}


	while ($content{$active_speaker_id}=~s/\s\s/ /m) {}
	while($content{$active_speaker_id}=~s/^\s//m){};while($content{$active_speaker_id}=~s/\s$//m){};
	if ($cut) {
	    $content{$active_speaker_id}=~s/\<lr\>\s*/\n/gms;
	    $content{$active_speaker_id}=~s/\n+/\n/gms;
	}
    }
}

sub acoustic_conditions() { # traitement des conditions acoustiques
	#analyse des conditions acoustiques :
	$conditions=0;
	if ($overlappingbackground ne "") {
	    $conditions=3;
	    if ($overlappingbackground =~ /(shh|speech|other)/) {
		$conditions=4;
	    }
	    if ($overlappingbackground =~ /off$/ ) { # cas d'un overlapping background � terminer � l'impression.
		$overlappingbackground="";
	    }
	}
	if ($dialect{$speaker_turn} eq "nonnative") {
	    push(@conditions_turn,5); #condition f5
	}
	@backup_conditions_turn=@conditions_turn;
	foreach $cn (@conditions_turn) {
	    if ($conditions<$cn) {
		if ($conditions!=0) {
		    if ($cn == 2 && $conditions < 2) {
			$conditions=$cn;
		    } else {
			$conditions=6;
		    }
		}
		else { $conditions=$cn; }
	    } else {
		if ($cn==2) {
		    $conditions=4;
		}
	    }
	}
	if ($conditions==6) {$conditions="fx";}
	    else { $conditions="f".$conditions;
	}
	$conditions_turn=$backup_conditions_turn;
}

sub bynum { # ordre de tri numerique (en ignorant le contenu alphabetique) pour le tri des locuteurs & themes
    &num($a) <=> &num($b)
}

sub num { # procedure utilisee par bynum pour obtenir le contenu numerique d'une chaine de caracteres
    ($string)=@_;
    $string=~tr/[a-zA-Z]/ /;
    return $string;
}

sub protect() { # procedure de protection d'un mot pour le traitement d'expressions regulieres
    my $string=$_[0];
    $string=~s/\(/\\\(/g;
    $string=~s/\)/\\\)/g;
    return $string;
}

#-------------- fin des procedures utilis�es pour le formattage

# procedures de gestion des messages d'erreurs/avertissements/...
sub verbose {
    if ($verbose) {
	print STDERR $_[0]."\n";
    }
}

sub warning {
    if ($warning) {
	print STDERR "WARNING: $_[0]\n";
    }
}
#------------- fin des procedures de gestion des erreurs et avertissements


__END__


=head1 NAME

parsetrs - transcriber .trs format parser

=head1 SYNOPSIS

parsetrs [-help|h] [-verbose|v] [-warning|w] [-outputformat|f format] [-output|o output_file] [-printevent|c] [-uppercase|u] [-lowercase|l] [-removetag|rmt "event1:desc1,event2:desc2"] [-removecontent|rmc  "event1:desc1,event2:desc2"] [-removesegment|rms "event1:desc1,event2:desc2"] [file1 file2 ...]
  
Description :

    parsetrs (v0.74) formats an xml transcriber document
    
Typical usage :

    parsetrs file.trs

    convert file.trs to stm NIST format. Ouput to STDOUT

    parsetrs -f txt file.trs

    convert file.trs to ascii text format. Ouput to STDOUT

for more extensive help try :

    prasetrs -man

=head2 Mises � jour

=over 8
=item B<-Nouveaut�s version 0.74>
    - compl�ment d�bogage balises pronounce

=item B<-Nouveaut�s version 0.73>
    - am�lioration format stm-ne et ctm-ne pour �valuation des entit�s nomm�es
    - prise en compte des balises pronounce "(.*:) prononciation + (1[1-9] cent...)
    - format lex am�lior�

=item B<-Nouveaut�s version 0.72>

    - correction des bugs sur les balises extent="next" par pr�traitement syst�matique

=item B<-Nouveaut�s version 0.72>

    - ajout des formats de sortie trs, mtdm, stm-ne 
    - modification des r�gles de conditions acoustiques (suite au changement de Transcriber 1.4.7)
    - ajout des support des balises pronounce sp�cifiques (19 cent... / URL)
    - inversion de la commande k (keep audiofilename au lieu de keep filename)
    - correction de la fonctionnalit� de postprocessing. fonction aussi bien avec STDOUT qu'avec la sortie
      en fichiers (e.g. parsetrs file.trs -p 'normalize'
    - ajout du comptage du temps pris par le programme � la sorite (en mode verbose)

=item B<-Nouveaut�s version 0.5 :>

    - possibilit� de supprimer certaines balises � la vol�e,
      ou au contraire de n'extraire que ces balises (utile pour
      entites nomm�es par exemple) (options -extract/-remove)

=item B<Nouveaut�s version 0.6 :>

    - conversion stm rendue plus compatible avec l'export transcriber 1.4.6 :
               - support des noms de locuteurs "global" ou non
               - gestion des conditions acoustiques bruit�es
               - multilocuteurs dans excluded_regions
    le support des tours � deux locuteurs aboutit toujours � des 
    "excluded regions"

=item B<Nouveaut�s version 0.61 :>

    - format de sortie par d�faut : stm au lieu de lexh
    - g�re 3 types d'ignore pour les balises : celles qu'on ne veut
                 pas voir (-rmt removetag), celles dont on ne veut pas voir
                 le contenu (-rmc removecontent) et celles pour lesquelles
                 il faut supprimer toute le segment correspondant (-rms)
    - rajout de l'option -w (warning)
    - conversion stm : 
               - correction des incompatibilit�s type "inter_segment_gap"
               - gestion des balises previous et next compatible (transform�es
                 en balises begin & end)
               - correction pour prise en compte du mode f1 (spontaneous)
               - r�solution du probl�me de bords pour les balises background en 
                 d�but/fin de tour.
               - suppression des eventaires et balises de prononciation
               - prise en compte des balises [lang] si elles ne concernent 
                 qu'un seul mot (on n'ignore alors pas le segment)
    - diff�rences persistant avec l'export stm transcriber 1.4.6:
               - split des segments comportant une balise background en deux
                 (ou plusieurs) segments de conditions acoustiques diff�rentes
               - apr�s un tour � deux locuteurs, l'export stm de transcriber
                 force la condition acoustique du tour suivante � f3, ce qui
                 n'est pas le cas ici
               - transcriber ignore les balises next
               - transcriber ne g�re pas les balises previous en d�but de turn
               - gestion diff�rentes du cas limite "mot [noise] [+noise]"
               - transcriber ne supporte pas les balises d�bordant d'une section
    - mise � jour du manuel

=item B<Nouveaut�s version 0.62 :>
    - correction de l'extraction de tags (option -e), maintenant valide


=head1 OPTIONS

=over 8

=item B<-help>

    Print a brief help message and exits.

=item B<-man>

    Prints this manual page and exits.

=item B<-verbose|v>
    
    Ouputs various messages. Use it to verbose files
    that are being parsed.

=item B<-warning|w>
    
    Reports warnings generated during the conversion process (sync problems,
    supressed segments...).

=item B<-output|o output_file_format>

    If you want to normalize many files, you perhaps want to do
    more than just cat them to the output. Use this option to save
    the output for each file.

    Example :

    parsetrs -f stm input_dir/*.xml -o output_dir/%s.stm

    will convert each .xml file stored in 'input_dir/'
    and store the result in 'output_dir/' with the same
    basename and the extension 'stm'.

=item B<-postprocess|p post-processing_command>

    Apply the command 'processing_command' before writing the
    output files (to be used with the -o option).

    Example :
    
    parsetrs -f "%speaker" -v input_dir/*.xml -o output_dir/%s.spk -p 'sort | uniq'

    will write the speaker list of each file to 'output_dir/*.spk' 

=item B<-outputformat|f output_format>
    
    Default is 'stm'.

    May be 'lexh' or 'stm','stm-ne', mdtm or 'full' or 'speech', 'text', or a
    preformatted string. In preformatted string (e.g. 
    "%transcription %filename %begin %end"), some fields will be 
    replaced by informations read from the transcription file :

       %filename       file name
       %begin          begining of current speech segment in seconds
       %end            end of current speech segment in seconds
       %transcription   transcribed text corresponding to the segment
       %conditions     acoustic conditions of the segment 
                      (experimental)
       %topic          topic of the section
       %speaker        the speaker of the turn
       %speakerid      id of the speaker
       %speakerdialect dialect of the speaker
       %speakername    name of the speaker
       %speakergenre   genre of the speaker
       %speakeraccent  accent of the speaker

    %speaker is a special preformatted string :
    %speaker <=>  %speakername-%speakerdialect-%speakeraccent-%speakergenre by default

    lexh, stm, full and speech are preformatted strings: 
    stm     <=>  %filename 1 %speaker %begin %end
                         <o,%conditions,%speakergenre> %transcription
    lexh     <=>  %transcription (%filename-%begin-%end)
    speech   <=>  (%filename-%speaker-%begin-%end)
    full     <=>  %transcription (%speaker-%conditions)
                                (%topic) (%filename-%begin-%end)
    text     <=>  %transcription

    for stm format, %speaker <=> %filename-%speakername"
    for speech, only the speech segments will be printed
    moreover, stm format uses by default these option :
    -rms "nontrans,language"   to ignore untranscriber segments, and 
                               foreign language segments
    -rmt "event:,pronounce:(?!pi),lexical" 
                               to remove events tags, pronounce tags (except
                               pi and pif), and lexical tags

=item B<-printevent|c>

    displays any event or comment appearing in the transcription
    in %transcription

=item B<-uppercase|u>

    convert all characters to uppercase

=item B<-lowercase|l>

    convert all characters to lowercase

=item B<-extract|e "event1:desc1,event2:desc2,..." > 

    extract (only displays) special events or events corresponding 
    to listed ones :

    parsetrs file.trs -e "noise:n,pronounce"

    will display only events with type noise and with desc tag equal
    to n, and every pronounce events. 

    usefull if combined with -c and/or -r


=item B<-removetag|rmt "event1:desc1,event2:desc2,..." > 
    
    supress events/events tags in the list event1:desc1 ,
    event2:desc2 , ...

    usefull for supressing noise events for example  : 

    parsetrs -c -rmt "noise"

=item B<-removesegment|rms "event1:desc1,event2:desc2,..." > 
    
    supress contents of events/events tags in the list event1:desc1 ,
    event2:desc2 , ...

    usefull for supressing segments with noise events for example  : 

    parsetrs -c -rmc "noise"

=item B<-respectcut|r>

    adds a \n (return) for every line, respecting line cuts of xml
    file and not sync cut of trancriber format. usefull combined with
    -e
    








=back


=cut




