package IO::Compress::Zip ;

use strict ;
use warnings;
use bytes;

use IO::Compress::Base::Common  2.074 qw(:Status );
use IO::Compress::RawDeflate 2.074 ();
use IO::Compress::Adapter::Deflate 2.074 ;
use IO::Compress::Adapter::Identity 2.074 ;
use IO::Compress::Zlib::Extra 2.074 ;
use IO::Compress::Zip::Constants 2.074 ;

use File::Spec();
use Config;

use Compress::Raw::Zlib  2.074 (); 

BEGIN
{
    eval { require IO::Compress::Adapter::Bzip2 ; 
           import  IO::Compress::Adapter::Bzip2 2.074 ; 
           require IO::Compress::Bzip2 ; 
           import  IO::Compress::Bzip2 2.074 ; 
         } ;
         
    eval { require IO::Compress::Adapter::Lzma ; 
           import  IO::Compress::Adapter::Lzma 2.074 ; 
           require IO::Compress::Lzma ; 
           import  IO::Compress::Lzma 2.074 ; 
         } ;
}


require Exporter ;

our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, %DEFLATE_CONSTANTS, $ZipError);

$VERSION = '2.074';
$ZipError = '';

@ISA = qw(IO::Compress::RawDeflate Exporter);
@EXPORT_OK = qw( $ZipError zip ) ;
%EXPORT_TAGS = %IO::Compress::RawDeflate::DEFLATE_CONSTANTS ;

push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;

$EXPORT_TAGS{zip_method} = [qw( ZIP_CM_STORE ZIP_CM_DEFLATE ZIP_CM_BZIP2 ZIP_CM_LZMA)];
push @{ $EXPORT_TAGS{all} }, @{ $EXPORT_TAGS{zip_method} };

Exporter::export_ok_tags('all');

sub new
{
    my $class = shift ;

    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$ZipError);    
    $obj->_create(undef, @_);

}

sub zip
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$ZipError);    
    return $obj->_def(@_);
}

sub isMethodAvailable
{
    my $method = shift;
    
    # Store & Deflate are always available
    return 1
        if $method == ZIP_CM_STORE || $method == ZIP_CM_DEFLATE ;
        
    return 1 
        if $method == ZIP_CM_BZIP2 and 
           defined $IO::Compress::Adapter::Bzip2::VERSION;
           
    return 1
        if $method == ZIP_CM_LZMA and
           defined $IO::Compress::Adapter::Lzma::VERSION;
           
    return 0;       
}

sub beforePayload
{
    my $self = shift ;

    if (*$self->{ZipData}{Sparse} ) {
        my $inc = 1024 * 100 ;
        my $NULLS = ("\x00" x $inc) ;
        my $sparse = *$self->{ZipData}{Sparse} ;
        *$self->{CompSize}->add( $sparse );
        *$self->{UnCompSize}->add( $sparse );
        
        *$self->{FH}->seek($sparse, IO::Handle::SEEK_CUR);
        
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32($NULLS, *$self->{ZipData}{CRC32})
            for 1 .. int $sparse / $inc;
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32(substr($NULLS, 0,  $sparse % $inc), 
                                         *$self->{ZipData}{CRC32})
            if $sparse % $inc;
    }
}

sub mkComp
{
    my $self = shift ;
    my $got = shift ;

    my ($obj, $errstr, $errno) ;

    if (*$self->{ZipData}{Method} == ZIP_CM_STORE) {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Identity::mkCompObject(
                                                 $got->getValue('level'),
                                                 $got->getValue('strategy')
                                                 );
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32(undef);
    }
    elsif (*$self->{ZipData}{Method} == ZIP_CM_DEFLATE) {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Deflate::mkCompObject(
                                                 $got->getValue('crc32'),
                                                 $got->getValue('adler32'),
                                                 $got->getValue('level'),
                                                 $got->getValue('strategy')
                                                 );
    }
    elsif (*$self->{ZipData}{Method} == ZIP_CM_BZIP2) {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Bzip2::mkCompObject(
                                                $got->getValue('blocksize100k'),
                                                $got->getValue('workfactor'),
                                                $got->getValue('verbosity')
                                               );
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32(undef);
    }
    elsif (*$self->{ZipData}{Method} == ZIP_CM_LZMA) {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Lzma::mkRawZipCompObject($got->getValue('preset'),
                                                                                 $got->getValue('extreme'),
                                                                                 );
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32(undef);
    }

    return $self->saveErrorString(undef, $errstr, $errno)
       if ! defined $obj;

    if (! defined *$self->{ZipData}{SizesOffset}) {
        *$self->{ZipData}{SizesOffset} = 0;
        *$self->{ZipData}{Offset} = new U64 ;
    }

    *$self->{ZipData}{AnyZip64} = 0
        if ! defined  *$self->{ZipData}{AnyZip64} ;

    return $obj;    
}

sub reset
{
    my $self = shift ;

    *$self->{Compress}->reset();
    *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32('');

    return STATUS_OK;    
}

sub filterUncompressed
{
    my $self = shift ;

    if (*$self->{ZipData}{Method} == ZIP_CM_DEFLATE) {
        *$self->{ZipData}{CRC32} = *$self->{Compress}->crc32();
    }
    else {
        *$self->{ZipData}{CRC32} = Compress::Raw::Zlib::crc32(${$_[0]}, *$self->{ZipData}{CRC32});

    }
}

sub canonicalName
{
    # This sub is derived from Archive::Zip::_asZipDirName

    # Return the normalized name as used in a zip file (path
    # separators become slashes, etc.).
    # Will translate internal slashes in path components (i.e. on Macs) to
    # underscores.  Discards volume names.
    # When $forceDir is set, returns paths with trailing slashes 
    #
    # input         output
    # .             '.'
    # ./a           a
    # ./a/b         a/b
    # ./a/b/        a/b
    # a/b/          a/b
    # /a/b/         a/b
    # c:\a\b\c.doc  a/b/c.doc      # on Windows
    # "i/o maps:whatever"   i_o maps/whatever   # on Macs

    my $name      = shift;
    my $forceDir  = shift ;

    my ( $volume, $directories, $file ) =
      File::Spec->splitpath( File::Spec->canonpath($name), $forceDir );
      
    my @dirs = map { $_ =~ s{/}{_}g; $_ } 
               File::Spec->splitdir($directories);

    if ( @dirs > 0 ) { pop (@dirs) if $dirs[-1] eq '' }   # remove empty component
    push @dirs, defined($file) ? $file : '' ;

    my $normalised_path = join '/', @dirs;

    # Leading directory separators should not be stored in zip archives.
    # Example:
    #   C:\a\b\c\      a/b/c
    #   C:\a\b\c.txt   a/b/c.txt
    #   /a/b/c/        a/b/c
    #   /a/b/c.txt     a/b/c.txt
    $normalised_path =~ s{^/}{};  # remove leading separator

    return $normalised_path;
}


sub mkHeader
{
    my $self  = shift;
    my $param = shift ;
    
    *$self->{ZipData}{LocalHdrOffset} = U64::clone(*$self->{ZipData}{Offset});
        
    my $comment = '';
    $comment = $param->valueOrDefault('comment') ;

    my $filename = '';
    $filename = $param->valueOrDefault('name') ;

    $filename = canonicalName($filename)
        if length $filename && $param->getValue('canonicalname') ;

    if (defined *$self->{ZipData}{FilterName} ) {
        local *_ = \$filename ;
        &{ *$self->{ZipData}{FilterName} }() ;
    }


    my $hdr = '';

    my $time = _unixToDosTime($param->getValue('time'));

    my $extra = '';
    my $ctlExtra = '';
    my $empty = 0;
    my $osCode = $param->getValue('os_code') ;
    my $extFileAttr = 0 ;
    
    # This code assumes Unix.
    # TODO - revisit this
    $extFileAttr = 0100644 << 16 
        if $osCode == ZIP_OS_CODE_UNIX ;

    if (*$self->{ZipData}{Zip64}) {
        $empty = IO::Compress::Base::Common::MAX32;

        my $x = '';
        $x .= pack "V V", 0, 0 ; # uncompressedLength   
        $x .= pack "V V", 0, 0 ; # compressedLength   
        
        # Zip64 needs to be first in extra field to workaround a Windows Explorer Bug
        # See http://www.info-zip.org/phpBB3/viewtopic.php?f=3&t=440 for details
        $extra .= IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_ZIP64, $x);
    }

    if (! $param->getValue('minimal')) {
        if ($param->parsed('mtime'))
        {
            $extra .= mkExtendedTime($param->getValue('mtime'), 
                                    $param->getValue('atime'), 
                                    $param->getValue('ctime'));

            $ctlExtra .= mkExtendedTime($param->getValue('mtime'));
        }

        if ( $osCode == ZIP_OS_CODE_UNIX )
        {
            if ( $param->getValue('want_exunixn') )
            {
                    my $ux3 = mkUnixNExtra( @{ $param->getValue('want_exunixn') }); 
                    $extra    .= $ux3;
                    $ctlExtra .= $ux3;
            }

            if ( $param->getValue('exunix2') )
            {
                    $extra    .= mkUnix2Extra( @{ $param->getValue('exunix2') }); 
                    $ctlExtra .= mkUnix2Extra();
            }
        }

        $extFileAttr = $param->getValue('extattr') 
            if defined $param->getValue('extattr') ;

        $extra .= $param->getValue('extrafieldlocal') 
            if defined $param->getValue('extrafieldlocal');

        $ctlExtra .= $param->getValue('extrafieldcentral') 
            if defined $param->getValue('extrafieldcentral');
    }

    my $method = *$self->{ZipData}{Method} ;
    my $gpFlag = 0 ;    
    $gpFlag |= ZIP_GP_FLAG_STREAMING_MASK
        if *$self->{ZipData}{Stream} ;

    $gpFlag |= ZIP_GP_FLAG_LZMA_EOS_PRESENT
        if $method == ZIP_CM_LZMA ;


    my $version = $ZIP_CM_MIN_VERSIONS{$method};
    $version = ZIP64_MIN_VERSION
        if ZIP64_MIN_VERSION > $version && *$self->{ZipData}{Zip64};

    my $madeBy = ($param->getValue('os_code') << 8) + $version;
    my $extract = $version;

    *$self->{ZipData}{Version} = $version;
    *$self->{ZipData}{MadeBy} = $madeBy;

    my $ifa = 0;
    $ifa |= ZIP_IFA_TEXT_MASK
        if $param->getValue('textflag');

    $hdr .= pack "V", ZIP_LOCAL_HDR_SIG ; # signature
    $hdr .= pack 'v', $extract   ; # extract Version & OS
    $hdr .= pack 'v', $gpFlag    ; # general purpose flag (set streaming mode)
    $hdr .= pack 'v', $method    ; # compression method (deflate)
    $hdr .= pack 'V', $time      ; # last mod date/time
    $hdr .= pack 'V', 0          ; # crc32               - 0 when streaming
    $hdr .= pack 'V', $empty     ; # compressed length   - 0 when streaming
    $hdr .= pack 'V', $empty     ; # uncompressed length - 0 when streaming
    $hdr .= pack 'v', length $filename ; # filename length
    $hdr .= pack 'v', length $extra ; # extra length
    
    $hdr .= $filename ;

    # Remember the offset for the compressed & uncompressed lengths in the
    # local header.
    if (*$self->{ZipData}{Zip64}) {
        *$self->{ZipData}{SizesOffset} = *$self->{ZipData}{Offset}->get64bit()
            + length($hdr) + 4 ;
    }
    else {
        *$self->{ZipData}{SizesOffset} = *$self->{ZipData}{Offset}->get64bit()
                                            + 18;
    }

    $hdr .= $extra ;


    my $ctl = '';

    $ctl .= pack "V", ZIP_CENTRAL_HDR_SIG ; # signature
    $ctl .= pack 'v', $madeBy    ; # version made by
    $ctl .= pack 'v', $extract   ; # extract Version
    $ctl .= pack 'v', $gpFlag    ; # general purpose flag (streaming mode)
    $ctl .= pack 'v', $method    ; # compression method (deflate)
    $ctl .= pack 'V', $time      ; # last mod date/time
    $ctl .= pack 'V', 0          ; # crc32
    $ctl .= pack 'V', $empty     ; # compressed length
    $ctl .= pack 'V', $empty     ; # uncompressed length
    $ctl .= pack 'v', length $filename ; # filename length

    *$self->{ZipData}{ExtraOffset} = length $ctl;
    *$self->{ZipData}{ExtraSize} = length $ctlExtra ;

    $ctl .= pack 'v', length $ctlExtra ; # extra length
    $ctl .= pack 'v', length $comment ;  # file comment length
    $ctl .= pack 'v', 0          ; # disk number start 
    $ctl .= pack 'v', $ifa       ; # internal file attributes
    $ctl .= pack 'V', $extFileAttr   ; # external file attributes

    # offset to local hdr
    if (*$self->{ZipData}{LocalHdrOffset}->is64bit() ) { 
        $ctl .= pack 'V', IO::Compress::Base::Common::MAX32 ;
    }
    else {
        $ctl .= *$self->{ZipData}{LocalHdrOffset}->getPacked_V32() ; 
    }
    
    $ctl .= $filename ;

    *$self->{ZipData}{Offset}->add32(length $hdr) ;

    *$self->{ZipData}{CentralHeader} = [ $ctl, $ctlExtra, $comment];

    return $hdr;
}

sub mkTrailer
{
    my $self = shift ;

    my $crc32 ;
    if (*$self->{ZipData}{Method} == ZIP_CM_DEFLATE) {
        $crc32 = pack "V", *$self->{Compress}->crc32();
    }
    else {
        $crc32 = pack "V", *$self->{ZipData}{CRC32};
    }

    my ($ctl, $ctlExtra, $comment) = @{ *$self->{ZipData}{CentralHeader} };   

    my $sizes ;
    if (! *$self->{ZipData}{Zip64}) {
        $sizes .= *$self->{CompSize}->getPacked_V32() ;   # Compressed size
        $sizes .= *$self->{UnCompSize}->getPacked_V32() ; # Uncompressed size
    }
    else {
        $sizes .= *$self->{CompSize}->getPacked_V64() ;   # Compressed size
        $sizes .= *$self->{UnCompSize}->getPacked_V64() ; # Uncompressed size
    }

    my $data = $crc32 . $sizes ;

    my $xtrasize  = *$self->{UnCompSize}->getPacked_V64() ; # Uncompressed size
       $xtrasize .= *$self->{CompSize}->getPacked_V64() ;   # Compressed size

    my $hdr = '';

    if (*$self->{ZipData}{Stream}) {
        $hdr  = pack "V", ZIP_DATA_HDR_SIG ;                       # signature
        $hdr .= $data ;
    }
    else {
        $self->writeAt(*$self->{ZipData}{LocalHdrOffset}->get64bit() + 14,  $crc32)
            or return undef;
        $self->writeAt(*$self->{ZipData}{SizesOffset}, 
                *$self->{ZipData}{Zip64} ? $xtrasize : $sizes)
            or return undef;
    }

    # Central Header Record/Zip64 extended field

    substr($ctl, 16, length $crc32) = $crc32 ;

    my $zip64Payload = '';

    # uncompressed length - only set zip64 if needed
    if (*$self->{UnCompSize}->isAlmost64bit()) { #  || *$self->{ZipData}{Zip64}) {
        $zip64Payload .= *$self->{UnCompSize}->getPacked_V64() ; 
    } else {
        substr($ctl, 24, 4) = *$self->{UnCompSize}->getPacked_V32() ;
    }

    # compressed length - only set zip64 if needed
    if (*$self->{CompSize}->isAlmost64bit()) { # || *$self->{ZipData}{Zip64}) {
        $zip64Payload .= *$self->{CompSize}->getPacked_V64() ; 
    } else {
        substr($ctl, 20, 4) = *$self->{CompSize}->getPacked_V32() ;
    }

    # Local Header offset
    $zip64Payload .= *$self->{ZipData}{LocalHdrOffset}->getPacked_V64()
        if *$self->{ZipData}{LocalHdrOffset}->is64bit() ; 

    # disk no - always zero, so don't need to include it.
    #$zip64Payload .= pack "V", 0    ; 

    my $zip64Xtra = '';
    
    if (length $zip64Payload) {
        $zip64Xtra = IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_ZIP64, $zip64Payload);
        
        substr($ctl, *$self->{ZipData}{ExtraOffset}, 2) = 
             pack 'v', *$self->{ZipData}{ExtraSize} + length $zip64Xtra;

        *$self->{ZipData}{AnyZip64} = 1;
    }

    # Zip64 needs to be first in extra field to workaround a Windows Explorer Bug
    # See http://www.info-zip.org/phpBB3/viewtopic.php?f=3&t=440 for details
    $ctl .= $zip64Xtra . $ctlExtra . $comment;
    
    *$self->{ZipData}{Offset}->add32(length($hdr));
    *$self->{ZipData}{Offset}->add( *$self->{CompSize} );
    push @{ *$self->{ZipData}{CentralDir} }, $ctl ;

    return $hdr;
}

sub mkFinalTrailer
{
    my $self = shift ;
        
    my $comment = '';
    $comment = *$self->{ZipData}{ZipComment} ;

    my $cd_offset = *$self->{ZipData}{Offset}->get32bit() ; # offset to start central dir

    my $entries = @{ *$self->{ZipData}{CentralDir} };
    
    *$self->{ZipData}{AnyZip64} = 1 
        if *$self->{ZipData}{Offset}->is64bit || $entries >= 0xFFFF ;      
           
    my $cd = join '', @{ *$self->{ZipData}{CentralDir} };
    my $cd_len = length $cd ;

    my $z64e = '';

    if ( *$self->{ZipData}{AnyZip64} ) {

        my $v  = *$self->{ZipData}{Version} ;
        my $mb = *$self->{ZipData}{MadeBy} ;
        $z64e .= pack 'v', $mb            ; # Version made by
        $z64e .= pack 'v', $v             ; # Version to extract
        $z64e .= pack 'V', 0              ; # number of disk
        $z64e .= pack 'V', 0              ; # number of disk with central dir
        $z64e .= U64::pack_V64 $entries   ; # entries in central dir on this disk
        $z64e .= U64::pack_V64 $entries   ; # entries in central dir
        $z64e .= U64::pack_V64 $cd_len    ; # size of central dir
        $z64e .= *$self->{ZipData}{Offset}->getPacked_V64() ; # offset to start central dir

        $z64e  = pack("V", ZIP64_END_CENTRAL_REC_HDR_SIG) # signature
              .  U64::pack_V64(length $z64e)
              .  $z64e ;

        *$self->{ZipData}{Offset}->add32(length $cd) ; 

        $z64e .= pack "V", ZIP64_END_CENTRAL_LOC_HDR_SIG; # signature
        $z64e .= pack 'V', 0              ; # number of disk with central dir
        $z64e .= *$self->{ZipData}{Offset}->getPacked_V64() ; # offset to end zip64 central dir
        $z64e .= pack 'V', 1              ; # Total number of disks 

        $cd_offset = IO::Compress::Base::Common::MAX32 ;
        $cd_len = IO::Compress::Base::Common::MAX32 if IO::Compress::Base::Common::isGeMax32 $cd_len ;
        $entries = 0xFFFF if $entries >= 0xFFFF ;
    }

    my $ecd = '';
    $ecd .= pack "V", ZIP_END_CENTRAL_HDR_SIG ; # signature
    $ecd .= pack 'v', 0          ; # number of disk
    $ecd .= pack 'v', 0          ; # number of disk with central dir
    $ecd .= pack 'v', $entries   ; # entries in central dir on this disk
    $ecd .= pack 'v', $entries   ; # entries in central dir
    $ecd .= pack 'V', $cd_len    ; # size of central dir
    $ecd .= pack 'V', $cd_offset ; # offset to start central dir
    $ecd .= pack 'v', length $comment ; # zipfile comment length
    $ecd .= $comment;

    return $cd . $z64e . $ecd ;
}

sub ckParams
{
    my $self = shift ;
    my $got = shift;
    
    $got->setValue('crc32' => 1);

    if (! $got->parsed('time') ) {
        # Modification time defaults to now.
        $got->setValue('time' => time) ;
    }

    if ($got->parsed('extime') ) {
        my $timeRef = $got->getValue('extime');
        if ( defined $timeRef) {
            return $self->saveErrorString(undef, "exTime not a 3-element array ref")   
                if ref $timeRef ne 'ARRAY' || @$timeRef != 3;
        }

        $got->setValue("mtime", $timeRef->[1]);
        $got->setValue("atime", $timeRef->[0]);
        $got->setValue("ctime", $timeRef->[2]);
    }
    
    # Unix2/3 Extended Attribute
    for my $name (qw(exunix2 exunixn))
    {
        if ($got->parsed($name) ) {
            my $idRef = $got->getValue($name);
            if ( defined $idRef) {
                return $self->saveErrorString(undef, "$name not a 2-element array ref")   
                    if ref $idRef ne 'ARRAY' || @$idRef != 2;
            }

            $got->setValue("uid", $idRef->[0]);
            $got->setValue("gid", $idRef->[1]);
            $got->setValue("want_$name", $idRef);
        }
    }

    *$self->{ZipData}{AnyZip64} = 1
        if $got->getValue('zip64');
    *$self->{ZipData}{Zip64} = $got->getValue('zip64');
    *$self->{ZipData}{Stream} = $got->getValue('stream');

    my $method = $got->getValue('method');
    return $self->saveErrorString(undef, "Unknown Method '$method'")   
        if ! defined $ZIP_CM_MIN_VERSIONS{$method};

    return $self->saveErrorString(undef, "Bzip2 not available")
        if $method == ZIP_CM_BZIP2 and 
           ! defined $IO::Compress::Adapter::Bzip2::VERSION;

    return $self->saveErrorString(undef, "Lzma not available")
        if $method == ZIP_CM_LZMA 
        and ! defined $IO::Compress::Adapter::Lzma::VERSION;

    *$self->{ZipData}{Method} = $method;

    *$self->{ZipData}{ZipComment} = $got->getValue('zipcomment') ;

    for my $name (qw( extrafieldlocal extrafieldcentral ))
    {
        my $data = $got->getValue($name) ;
        if (defined $data) {
            my $bad = IO::Compress::Zlib::Extra::parseExtraField($data, 1, 0) ;
            return $self->saveErrorString(undef, "Error with $name Parameter: $bad")
                if $bad ;

            $got->setValue($name, $data) ;
        }
    }

    return undef
        if defined $IO::Compress::Bzip2::VERSION
            and ! IO::Compress::Bzip2::ckParams($self, $got);

    if ($got->parsed('sparse') ) {
        *$self->{ZipData}{Sparse} = $got->getValue('sparse') ;
        *$self->{ZipData}{Method} = ZIP_CM_STORE;
    }

    if ($got->parsed('filtername')) {
        my $v = $got->getValue('filtername') ;
        *$self->{ZipData}{FilterName} = $v
            if ref $v eq 'CODE' ;
    }

    return 1 ;
}

sub outputPayload
{
    my $self = shift ;
    return 1 if *$self->{ZipData}{Sparse} ;
    return $self->output(@_);
}




our %PARAMS = (            
            'stream'    => [IO::Compress::Base::Common::Parse_boolean,   1],
           #'store'     => [IO::Compress::Base::Common::Parse_boolean,   0],
            'method'    => [IO::Compress::Base::Common::Parse_unsigned,  ZIP_CM_DEFLATE],
            
            'minimal'   => [IO::Compress::Base::Common::Parse_boolean,   0],
            'zip64'     => [IO::Compress::Base::Common::Parse_boolean,   0],
            'comment'   => [IO::Compress::Base::Common::Parse_any,       ''],
            'zipcomment'=> [IO::Compress::Base::Common::Parse_any,       ''],
            'name'      => [IO::Compress::Base::Common::Parse_any,       ''],
            'filtername'=> [IO::Compress::Base::Common::Parse_code,      undef],
            'canonicalname'=> [IO::Compress::Base::Common::Parse_boolean,   0],
            'time'      => [IO::Compress::Base::Common::Parse_any,       undef],
            'extime'    => [IO::Compress::Base::Common::Parse_any,       undef],
            'exunix2'   => [IO::Compress::Base::Common::Parse_any,       undef], 
            'exunixn'   => [IO::Compress::Base::Common::Parse_any,       undef], 
            'extattr'   => [IO::Compress::Base::Common::Parse_any, 
                    $Compress::Raw::Zlib::gzip_os_code == 3 
                        ? 0100644 << 16 
                        : 0],
            'os_code'   => [IO::Compress::Base::Common::Parse_unsigned,  $Compress::Raw::Zlib::gzip_os_code],
            
            'textflag'  => [IO::Compress::Base::Common::Parse_boolean,   0],
            'extrafieldlocal'  => [IO::Compress::Base::Common::Parse_any,    undef],
            'extrafieldcentral'=> [IO::Compress::Base::Common::Parse_any,    undef],

            # Lzma
            'preset'   => [IO::Compress::Base::Common::Parse_unsigned, 6],
            'extreme'  => [IO::Compress::Base::Common::Parse_boolean,  0],

            # For internal use only         
            'sparse'    => [IO::Compress::Base::Common::Parse_unsigned,  0],

            IO::Compress::RawDeflate::getZlibParams(),
            defined $IO::Compress::Bzip2::VERSION
                ? IO::Compress::Bzip2::getExtraParams()
                : ()
                
  
                );

sub getExtraParams
{
    return %PARAMS ;
}

sub getInverseClass
{
    return ('IO::Uncompress::Unzip',
                \$IO::Uncompress::Unzip::UnzipError);
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $filename = shift ;

    if (IO::Compress::Base::Common::isaScalar($filename))
    {
        $params->setValue(zip64 => 1)
            if IO::Compress::Base::Common::isGeMax32 length (${ $filename }) ;

        return ;
    }

    my ($mode, $uid, $gid, $size, $atime, $mtime, $ctime) ;
    if ( $params->parsed('storelinks') )
    {
        ($mode, $uid, $gid, $size, $atime, $mtime, $ctime) 
                = (lstat($filename))[2, 4,5,7, 8,9,10] ;
    }
    else
    {
        ($mode, $uid, $gid, $size, $atime, $mtime, $ctime) 
                = (stat($filename))[2, 4,5,7, 8,9,10] ;
    }

    $params->setValue(textflag => -T $filename )
        if ! $params->parsed('textflag');

    $params->setValue(zip64 => 1)
        if IO::Compress::Base::Common::isGeMax32 $size ;

    $params->setValue('name' => $filename)
        if ! $params->parsed('name') ;

    $params->setValue('time' => $mtime) 
        if ! $params->parsed('time') ;
    
    if ( ! $params->parsed('extime'))
    {
        $params->setValue('mtime' => $mtime) ;
        $params->setValue('atime' => $atime) ;
        $params->setValue('ctime' => undef) ; # No Creation time
        # TODO - see if can fillout creation time on non-Unix
    }

    # NOTE - Unix specific code alert
    if (! $params->parsed('extattr'))
    {
        use Fcntl qw(:mode) ;
        my $attr = $mode << 16;
        $attr |= ZIP_A_RONLY if ($mode & S_IWRITE) == 0 ;
        $attr |= ZIP_A_DIR   if ($mode & S_IFMT  ) == S_IFDIR ;
        
        $params->setValue('extattr' => $attr);
    }

    $params->setValue('want_exunixn', [$uid, $gid]);
    $params->setValue('uid' => $uid) ;
    $params->setValue('gid' => $gid) ;
    
}

sub mkExtendedTime
{
    # order expected is m, a, c

    my $times = '';
    my $bit = 1 ;
    my $flags = 0;

    for my $time (@_)
    {
        if (defined $time)
        {
            $flags |= $bit;
            $times .= pack("V", $time);
        }

        $bit <<= 1 ;
    }

    return IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_EXT_TIMESTAMP,
                                                 pack("C", $flags) .  $times);
}

sub mkUnix2Extra
{
    my $ids = '';
    for my $id (@_)
    {
        $ids .= pack("v", $id);
    }

    return IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_INFO_ZIP_UNIX2, 
                                                 $ids);
}

sub mkUnixNExtra
{
    my $uid = shift;
    my $gid = shift;

    # Assumes UID/GID are 32-bit
    my $ids ;
    $ids .= pack "C", 1; # version
    $ids .= pack "C", $Config{uidsize};
    $ids .= pack "V", $uid;
    $ids .= pack "C", $Config{gidsize};
    $ids .= pack "V", $gid;

    return IO::Compress::Zlib::Extra::mkSubField(ZIP_EXTRA_ID_INFO_ZIP_UNIXN, 
                                                 $ids);
}


sub _unixToDosTime    # Archive::Zip::Member
{
	my $time_t = shift;
    
    # TODO - add something to cope with unix time < 1980 
	my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($time_t);
	my $dt = 0;
	$dt += ( $sec >> 1 );
	$dt += ( $min << 5 );
	$dt += ( $hour << 11 );
	$dt += ( $mday << 16 );
	$dt += ( ( $mon + 1 ) << 21 );
	$dt += ( ( $year - 80 ) << 25 );
	return $dt;
}

1;

__END__

