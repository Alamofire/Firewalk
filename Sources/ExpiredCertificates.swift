//
//  ExpiredCertificates.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

// P-256 certificates generated with OpenSSL: a root CA and two intermediate CAs valid until 2100, and a leaf that expired
// in 2020. The key is only for this deliberately invalid test chain.

/// PEM encoded certificates and key served on `--expired-tls-port`.
enum ExpiredCertificates {
    static let leaf = """
    -----BEGIN CERTIFICATE-----
    MIICCjCCAbCgAwIBAgIQOxnwVcZd1Z6UKRi6wC3U+zAKBggqhkjOPQQDAjBAMREw
    DwYDVQQKDAhGaXJld2FsazErMCkGA1UEAwwiRmlyZXdhbGsgRXhwaXJlZCBJbnRl
    cm1lZGlhdGUgQ0EgMjAeFw0yMDAxMDEwMDAwMDBaFw0yMDAxMDIwMDAwMDBaMCcx
    ETAPBgNVBAoMCEZpcmV3YWxrMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjO
    PQIBBggqhkjOPQMBBwNCAARwI0xEpQuyhPBbFHLm/Md9pk7C1uV+OZOqtS1PunjW
    jBGMikBX/gnWaOR1T2DRnO/lxfAhn8PjW7CuDpN49gf4o4GkMIGhMAwGA1UdEwEB
    /wQCMAAwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMBMCwGA1Ud
    EQQlMCOCCWxvY2FsaG9zdIcEfwAAAYcQAAAAAAAAAAAAAAAAAAAAATAdBgNVHQ4E
    FgQUeMMv2JHSspVSC+eJt/zjgNzxeIswHwYDVR0jBBgwFoAUwVT028JAz3/mAgt9
    t8vypkbqY+4wCgYIKoZIzj0EAwIDSAAwRQIhANKuVOYywhrpVWWFuyZ7ucI3swsR
    JAtSq32jIKWqqhFNAiBE5Ih2hQUW0+6VrhnfKnNn1CathZ+FzyOJLzd0mEfycA==
    -----END CERTIFICATE-----
    """

    static let intermediate2 = """
    -----BEGIN CERTIFICATE-----
    MIIB5zCCAY2gAwIBAgIRALIkjOS0fCpw3MRFhVJtaaQwCgYIKoZIzj0EAwIwQDER
    MA8GA1UECgwIRmlyZXdhbGsxKzApBgNVBAMMIkZpcmV3YWxrIEV4cGlyZWQgSW50
    ZXJtZWRpYXRlIENBIDEwIBcNMjAwMTAxMDAwMDAwWhgPMjEwMDAxMDEwMDAwMDBa
    MEAxETAPBgNVBAoMCEZpcmV3YWxrMSswKQYDVQQDDCJGaXJld2FsayBFeHBpcmVk
    IEludGVybWVkaWF0ZSBDQSAyMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEBRwU
    5mgufBOHRrjrM+5qp4zOXMX4fSSbsTex23gCqFwOLPYUfkc0lN4G0uAkub5tWfQE
    7MdJ4Ievx4jji/dn0aNmMGQwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8E
    BAMCAQYwHQYDVR0OBBYEFMFU9NvCQM9/5gILfbfL8qZG6mPuMB8GA1UdIwQYMBaA
    FH9MpFjgPE46kp+RAYUm1YVH6wvBMAoGCCqGSM49BAMCA0gAMEUCIQDitzGUIF9E
    vCaxOA7h2K0V4p97+z921MI7w353ZZirRgIgdN2bddrGqRjKchZLBBjyA/64nOND
    bRhykeGzjscve5c=
    -----END CERTIFICATE-----
    """

    static let intermediate1 = """
    -----BEGIN CERTIFICATE-----
    MIIB3TCCAYKgAwIBAgIQAkB6I8oS4iGmjlRGIsLwNTAKBggqhkjOPQQDAjA2MREw
    DwYDVQQKDAhGaXJld2FsazEhMB8GA1UEAwwYRmlyZXdhbGsgRXhwaXJlZCBSb290
    IENBMCAXDTIwMDEwMTAwMDAwMFoYDzIxMDAwMTAxMDAwMDAwWjBAMREwDwYDVQQK
    DAhGaXJld2FsazErMCkGA1UEAwwiRmlyZXdhbGsgRXhwaXJlZCBJbnRlcm1lZGlh
    dGUgQ0EgMTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABKsB6E6PZLLisjCJBEFy
    diXjBearbA9bxTkXxxS0J2/ttWBaLoiyd6lVEbtbDAUZK6nJn7Y9ibM6+3MwN6Fd
    8eijZjBkMBIGA1UdEwEB/wQIMAYBAf8CAQEwDgYDVR0PAQH/BAQDAgEGMB0GA1Ud
    DgQWBBR/TKRY4DxOOpKfkQGFJtWFR+sLwTAfBgNVHSMEGDAWgBQ2fK7q9dtAaImD
    s8YhReI+LFxX4zAKBggqhkjOPQQDAgNJADBGAiEA7vG0bTrEFQ3igUi48MKR6gnN
    HIQwkvUGsPywmzvE0/wCIQDIsl2o9oIDdTujIFU+w/QAsFkb9QjJUm2CZZpb2hy7
    1w==
    -----END CERTIFICATE-----
    """

    static let root = """
    -----BEGIN CERTIFICATE-----
    MIIBrzCCAVSgAwIBAgIQPzjoVsa7J9cT+Z91Db+bATAKBggqhkjOPQQDAjA2MREw
    DwYDVQQKDAhGaXJld2FsazEhMB8GA1UEAwwYRmlyZXdhbGsgRXhwaXJlZCBSb290
    IENBMCAXDTIwMDEwMTAwMDAwMFoYDzIxMDAwMTAxMDAwMDAwWjA2MREwDwYDVQQK
    DAhGaXJld2FsazEhMB8GA1UEAwwYRmlyZXdhbGsgRXhwaXJlZCBSb290IENBMFkw
    EwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEgHBrwlzFoCM2NY8p5RKdnhgiESaTnkZY
    PbfkcUn0BWs+GjZSQHOmv3HP4r6aX3znX+qADjmFDAvCjjMhx6UPIKNCMEAwDwYD
    VR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFDZ8rur120Bo
    iYOzxiFF4j4sXFfjMAoGCCqGSM49BAMCA0kAMEYCIQDnpURUvkHgPR3pJ7F9je4l
    0Uypt3oHbUecI01QfWshjwIhAKOBxdi5vwcmNMykXD+TeVH1RCEaoXjMVT8IbKDU
    Jlek
    -----END CERTIFICATE-----
    """

    static let leafPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgKLBIjrYUfYlh5VDQ
    MOWlzKp3TGAQ/7UVgVUf3c8VQw+hRANCAARwI0xEpQuyhPBbFHLm/Md9pk7C1uV+
    OZOqtS1PunjWjBGMikBX/gnWaOR1T2DRnO/lxfAhn8PjW7CuDpN49gf4
    -----END PRIVATE KEY-----
    """
}
