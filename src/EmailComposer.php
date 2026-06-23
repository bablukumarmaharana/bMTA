<?php
class EmailComposer {
    /**
     * Build a raw MIME message string with multipart/alternative and attachments.
     */
    public static function build(string $from, string $to, string $subject,
                                 string $html, string $text = '',
                                 string $amp = '', array $customHeaders = [],
                                 array $attachments = []): string {
        $boundary     = '=_NextPart_' . md5(uniqid());
        $altBoundary  = '=_AltPart_' . md5(uniqid());
        $message = '';

        // Headers
        $message .= "From: {$from}\r\n";
        $message .= "To: {$to}\r\n";
        $message .= "Subject: =?UTF-8?B?" . base64_encode($subject) . "?=\r\n";
        $message .= "MIME-Version: 1.0\r\n";
        foreach ($customHeaders as $name => $value) {
            // Filter out dangerous headers
            if (!in_array(strtolower($name), ['from','to','subject','mime-version','content-type'])) {
                $message .= "{$name}: {$value}\r\n";
            }
        }
        $message .= "Content-Type: multipart/mixed; boundary=\"{$boundary}\"\r\n\r\n";
        $message .= "This is a multi-part message in MIME format.\r\n--{$boundary}\r\n";

        // Alternative part (text, html, amp)
        $hasText = !empty($text);
        $hasHtml = !empty($html);
        $hasAmp  = !empty($amp);
        if ($hasText || $hasHtml || $hasAmp) {
            $message .= "Content-Type: multipart/alternative; boundary=\"{$altBoundary}\"\r\n\r\n";
            if ($hasText) {
                $message .= "--{$altBoundary}\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n{$text}\r\n";
            }
            if ($hasHtml) {
                $message .= "--{$altBoundary}\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n{$html}\r\n";
            }
            if ($hasAmp) {
                $message .= "--{$altBoundary}\r\nContent-Type: text/x-amp-html; charset=UTF-8\r\n\r\n{$amp}\r\n";
            }
            $message .= "--{$altBoundary}--\r\n";
        }

        // Attachments
        foreach ($attachments as $att) {
            $filePath = $att['path'];
            $filename = $att['filename'];
            $mime     = $att['mime'] ?? 'application/octet-stream';
            if (!file_exists($filePath)) continue;
            $content  = chunk_split(base64_encode(file_get_contents($filePath)));
            $message .= "--{$boundary}\r\n";
            $message .= "Content-Type: {$mime}; name=\"{$filename}\"\r\n";
            $message .= "Content-Disposition: attachment; filename=\"{$filename}\"\r\n";
            $message .= "Content-Transfer-Encoding: base64\r\n\r\n";
            $message .= $content . "\r\n";
        }
        $message .= "--{$boundary}--\r\n";
        return $message;
    }
}