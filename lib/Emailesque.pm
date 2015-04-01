# ABSTRACT: Lightweight To-The-Point Email
package Emailesque;

use Carp;
use File::Slurp;
use Email::AddressParser;
use Email::Sender::Transport::Sendmail;
use Email::Sender::Transport::SMTP;
use Email::Stuffer;

use Exporter 'import';
our @EXPORT = qw(email);

use parent 'Data::Object::Hash';

# VERSION

my %headers = map {
    my $name = lc $_;
       $name =~ s/\W+/_/g;
       $name => $_;
}
my @headers = (
    'Alternate-Recipient',
    'Apparently-To',
    'Approved',
    'Approved-By',
    'Autoforwarded',
    'Auto-Forwarded',
    'Bcc',
    'Cache-Post-Path',
    'Cc',
    'Comments',
    'Content-Alias',
    'Content-Alternative',
    'Content-Base',
    'Content-Class',
    'Content-Conversion',
    'Content-Description',
    'Content-Disposition',
    'Content-Features',
    'Content-ID',
    'Content-Identifier',
    'Content-Language',
    'Content-Length',
    'Content-Location',
    'Content-MD5',
    'Content-Return',
    'Content-SGML-Entity',
    'Content-Transfer-Encoding',
    'Content-Type',
    'Control',
    'Conversion',
    'Conversion-With-Loss',
    'Date',
    'Delivered-To',
    'Delivery-Date',
    'Disclose-Recipients',
    'Disposition-Notification-Options',
    'Disposition-Notification-To',
    'Distribution',
    'Encoding',
    'Errors-To',
    'Envelope-ID',
    'Expires',
    'Expiry-Date',
    'Fcc',
    'Followup-To',
    'For-Approval',
    'For-Comment',
    'For-Handling',
    'From',
    'Generate-Delivery-Report',
    'Importance',
    'In-Reply-To',
    'Incomplete-Copy',
    'Injector-Info',
    'Keywords',
    'Language',
    'Lines',
    'List-Archive',
    'List-Digest',
    'List-ID',
    'List-Owner',
    'List-Post',
    'List-Software',
    'List-Subscribe',
    'List-Unsubscribe',
    'List-URL',
    'Mail-Copies-To',
    'Mail-Reply-Requested-By',
    'Mail-System-Version',
    'Mailer',
    'Mailing-List',
    'Message-ID',
    'Message-Type',
    'MIME-Version',
    'Newsgroups',
    'NNTP-Posting-Date',
    'NNTP-Posting-Host',
    'NNTP-Posting-Time',
    'NNTP-Proxy-Relay',
    'Obsoletes',
    'Old-Date',
    'Old-X-Envelope-From',
    'Old-X-Envelope-To',
    'Organisation',
    'Organization',
    'Original-Encoded-Information-Types',
    'Original-Recipient',
    'Originating-Client',
    'Originator',
    'Originator-Info',
    'Path',
    'Phone',
    'Posted-To',
    'Precedence',
    'Prevent-NonDelivery-Report',
    'Priority',
    'Read-Receipt-To',
    'Received',
    'References',
    'Replaces',
    'Reply-By',
    'Reply-To',
    'Resent-bcc',
    'Resent-cc',
    'Resent-Date',
    'Resent-From',
    'Resent-Message-ID',
    'Resent-Reply-To',
    'Resent-Sender',
    'Resent-Subject',
    'Resent-To',
    'Return-Path',
    'Return-Receipt-Requested',
    'Return-Receipt-To',
    'See-Also',
    'Sender',
    'Sensitivity',
    'Speech-Act',
    'Status',
    'Subject',
    'Summary',
    'Supersedes',
    'To',
    'Translated-By',
    'Translation-Of',
    'User-Agent',
    'X-Abuse-Info',
    'X-Accept-Language',
    'X-Admin',
    'X-Article-Creation-Date',
    'X-Attribution',
    'X-Authenticated-IP',
    'X-Authenticated-Sender',
    'X-Authentication-Warning',
    'X-Cache',
    'X-Comments',
    'X-Complaints-To',
    'X-Confirm-reading-to',
    'X-Envelope-From',
    'X-Envelope-To',
    'X-Face',
    'X-Flags',
    'X-Folder',
    'X-Http-Proxy',
    'X-Http-User-Agent',
    'X-IMAP',
    'X-Last-Updated',
    'X-List-Host',
    'X-Listserver',
    'X-Loop',
    'X-Mailer',
    'X-Mailer-Info',
    'X-Mailing-List',
    'X-MIME-Autoconverted',
    'X-MimeOLE',
    'X-MIMETrack',
    'X-MSMail-Priority',
    'X-MyDeja-Info',
    'X-Newsreader',
    'X-NNTP-Posting-Host',
    'X-No-Archive',
    'X-Notice',
    'X-Orig-Message-ID',
    'X-Original-Envelope-From',
    'X-Original-NNTP-Posting-Host',
    'X-Original-Trace',
    'X-OriginalArrivalTime',
    'X-Originating-IP',
    'X-PMFLAGS',
    'X-Posted-By',
    'X-Posting-Agent',
    'X-Priority',
    'X-RCPT-TO',
    'X-Report',
    'X-Report-Abuse-To',
    'X-Sender',
    'X-Server-Date',
    'X-Trace',
    'X-UIDL',
    'X-UML-Sequence',
    'X-URI',
    'X-URL',
    'X-X-Sender',
);

sub email {
    unshift @_, __PACKAGE__->new({}) and goto &send;
}

sub prepare_address {
    my ($self, $field, @arguments) = @_;

    my $headers = $self->get('headers');
    my $value   = $headers->get($field);

    return join ",", map $_->format, Email::AddressParser->parse(
        $value->isa('Data::Object::Array')
            ? $value->join(',')->data
            : $value->data
    );
}

sub prepare_package {
    my ($self, $options, @arguments) = @_;

    $options = $self->merge($options) if $options;

    my $stuff   = Email::Stuffer->new;
    my $email   = $self->new($options->data // {});

    # initialize headers
    my $headers = $email->get('headers');
       $headers = $email->set('headers' => {}) if not $headers;

    # extract headers
    for my $key (keys %headers) {
        $headers->set($headers{$key}, $email->delete($key))
            if $email->defined($key);
    }

    # required fields
    my $required = $headers->filter_include(qw(From Subject To));
    confess "Can't send email without a to, from, and subject property"
        unless $required->values->count == 3;

    # process address headers
    my @address_headers = qw(
        Abuse-Reports-To
        Apparently-To
        Delivered-To
        Disposition-Notification-To
        Errors-To
        Followup-To
        In-Reply-To
        Mail-Copies-To
        Old-X-Envelope-To
        Posted-To
        Read-Receipt-To
        Resent-Reply-To
        Resent-To
        Return-Receipt-To
        X-Complaints-To
        X-Envelope-To
        X-Report-Abuse-To
    );
    for my $key (qw(Cc Bcc From Reply-To To), @address_headers) {
        $stuff->header($key => $email->prepare_address($key))
            if $headers->defined($key)
    }

    # process subject
    $stuff->subject($headers->get('Subject')->data)
        if $headers->defined('Subject');

    # process message
    if ($email->defined('message')) {
        my $type     = $email->get('type');
        my $message  = $email->get('message');
        my $html_msg = $email->lookup('message.html');
        my $text_msg = $email->lookup('message.text');

        # multipart send using plain text and html
        if (($type and lc($type) eq 'multi') or ($html_msg and $text_msg)) {
            $stuff->html_body("$html_msg") if defined $html_msg;
            $stuff->text_body("$text_msg") if defined $text_msg;
        }
        elsif (($type and lc($type) ne 'multi') and $message) {
            # standard send using html or plain text
            $stuff->html_body("$message") if $type and $type eq 'html';
            $stuff->text_body("$message") if $type and $type eq 'text';
        }
    }

    confess "Can't send email without a message property"
        unless $email->defined('message');

    # process additional headers
    my %excluded_headers = map { $_ => 1 } @address_headers, qw(
        Cc
        Bcc
        From
        Reply-To
        Subject
        To
    );
    for my $key (grep { !$excluded_headers{$_} } @headers) {
        $stuff->header($key => $headers->get($key)->data)
            if $headers->defined($key)
    }

    # process attachments - old behavior
    if (my $attachments = $email->get('attach')) {
        if ($attachments->isa('Data::Object::Array')) {
            my %files = ($attachments->list);
            foreach my $file (keys %files) {
                if ($files{$file}) {
                    my $data = read_file($files{$file}, binmode => ':raw');
                    $stuff->attach($data, name => $file, filename => $file);
                }
                else {
                    $stuff->attach_file($file);
                }
            }
        }
    }
    # process attachments - new behavior
    if (my $attachments = $email->get('files')) {
        if ($attachments->isa('Data::Object::Array')) {
            $stuff->attach_file($_->data) for ($attachments->list);
        }
    }

    # transport email explicitly
    $stuff->transport(@arguments) if @arguments;
    return $stuff if @arguments;

    # transport email implicitly
    my $driver   = $email->get('driver')->data;
    my $sendmail = lc($driver) eq lc('sendmail');
    my $smtpmail = lc($driver) eq lc('smtp');

    if ($sendmail) {
        my $path = $email->get('path')->data;

        $path ||= '/usr/bin/sendmail'  if -f '/usr/bin/sendmail';
        $path ||= '/usr/sbin/sendmail' if -f '/usr/sbin/sendmail';

        $stuff->transport('Sendmail' => (sendmail => $path));
    }

    if ($smtpmail) {
        my @parameters = ();
        for my $key (qw(host port ssl)) {
            my %map = (
                user => 'sasl_username',
                pass => 'sasl_password',
            );
            $key = $map{$key} // $key;
            push @parameters, $key, $email->get($key)->data
                if $email->defined($key);
        }

        push @parameters, 'proto' => 'tcp'; # no longer used
        push @parameters, 'reuse' => 1;     # no longer used

        $stuff->transport('SMTP' => @parameters);
    }

    return $stuff;
}

sub send {
    my ($self, $options, @arguments) = @_;
    my $package = $self->prepare_package($options, @arguments);
    return $package->send;
}

1;

=encoding utf8

=head1 SYNOPSIS

    use Emailesque;

    email {
        to      => '...',
        from    => '...',
        subject => '...',
        message => '...',
    };

=head1 DESCRIPTION

Emailesque provides an easy way of handling text or html email messages
with or without attachments. Simply define how you wish to send the email,
then call the email keyword passing the necessary parameters as outlined above.
This module is basically a wrapper around the email interface Email::Stuffer.
The following is an example of the object-oriented interface:

    use Emailesque;

    my $email = Emailesque->new({
        to      => '...',
        from    => '...',
        subject => '...',
        message => '...',
        files   => ['/path/to/file/1', '/path/to/file/2'],
    });

    $email->send;

The Emailesque object-oriented interface is designed to accept parameters at
instatiation and when calling the send method. This allows you to build-up an
email object with a few base parameters, then create and send multiple email
messages by calling the send method with only the unique parameters. The
following is an example of that:

    use Emailesque;

    my $email = Emailesque->new({
        from    => '...',
        subject => '...',
        type    => 'html',
        headers => {
            "X-Mailer" => "MyApp-Newletter 0.019876"
        }
    });

    for my $email (@emails) {
        $email->send({
            to      => $email,
            message => custom_email_message_for($email),
        });
    }

The default email format is plain-text, this can be changed to html by setting
the option 'type' to 'html'. The following are options that can be passed within
the hashref of arguments to the keyword, constructor and/or the send method:

    # send message to
    to => $email_recipient

    # send messages from
    from => $mail_sender

    # email subject
    subject => 'email subject line'

    # message body (must set type to multi)
    message => 'html or plain-text data'
    message => {
        text => $text_message,
        html => $html_messase,
    }

    # email message content type
    type => 'text'
    type => 'html'
    type => 'multi'

    # carbon-copy other email addresses
    cc => 'user@site.com'
    cc => 'user_a@site.com, user_b@site.com, user_c@site.com'

    # blind carbon-copy other email addresses
    bcc => 'user@site.com'
    bcc => 'user_a@site.com, user_b@site.com, user_c@site.com'

    # specify where email responses should be directed
    reply_to => 'other_email@website.com'

    # attach files to the email
    # set attachment name to undef to use the filename
    attach => [
        $filepath => undef,
    ]

    # send additional (specialized) headers
    headers => {
        "X-Mailer" => "SPAM-THE-WORLD-BOT 1.23456789"
    }

=head1 ADDITIONAL EXAMPLES

    # Handle Email Failures

    my $result = email {
            to      => '...',
            subject => '...',
            message => $msg,
            attach  => [
                'filename' => '/path/to/file'
            ]
        };

    die $result->message if ref($result) =~ /failure/i;

    # Add More Email Headers

    email {
        to      => '...',
        subject => '...',
        message => $msg,
        headers => {
            "X-Mailer" => 'SPAM-THE-WORLD-BOT 1.23456789',
            "X-Accept-Language" => 'en'
        }
    };

    # Send Text and HTML Email together

    email {
        to      => '...',
        subject => '...',
        type    => 'multi',
        message => {
            text => $txt,
            html => $html,
        }
    };

    # Send mail via SMTP with SASL authentication

    {
        ...,
        driver  => 'smtp',
        host    => 'smtp.googlemail.com',
        user    => 'account@gmail.com',
        pass    => '****'
    }

    # Send mail to/from Google (gmail)

    {
        ...,
        ssl     => 1,
        driver  => 'smtp',
        host    => 'smtp.googlemail.com',
        port    => 465,
        user    => 'account@gmail.com',
        pass    => '****'
    }

    # Set headers to be issued with message

    {
        ...,
        from => '...',
        subject => '...',
        headers => {
            'X-Mailer' => 'MyApp 1.0',
            'X-Accept-Language' => 'en'
        }
    }

    # Send email using sendmail, path is optional

    {
        ...,
        driver  => 'sendmail',
        path    => '/usr/bin/sendmail',
    }

=cut
