<?php

/**
 *   PHP Library - Remember The Milk
 *
 *   @author Adam Magaña
 *   @since September 9th, 2011
 *   @see http://www.rememberthemilk.com/services/api/
 *
 *   License (The MIT License)
 *
 *   Copyright (c) 2011 Adam Magaña <adammagana@gmail.com>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining
 *   a copy of this software and associated documentation files (the
 *   'Software'), to deal in the Software without restriction, including
 *   without limitation the rights to use, copy, modify, merge, publish,
 *   distribute, sublicense, and/or sell copies of the Software, and to
 *   permit persons to whom the Software is furnished to do so, subject to
 *   the following conditions:
 *
 *   The above copyright notice and this permission notice shall be
 *   included in all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
 *   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 *   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 *   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 *   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 *   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 *   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

namespace WorkOfStan\LembreSeDoLeite;

class RTM
{

    /** @var string */
    private $authUrl = 'https://www.rememberthemilk.com/services/auth/';

    /** @var string */
    private $baseUrl = 'https://api.rememberthemilk.com/services/rest/';

    /** @var string */
    private $appKey;

    /** @var string */
    private $appSecret;

    /** @var string */
    private $permissions;

    /** @var string */
    private $format;

    /**
     * CONSTRUCTOR
     *
     * @param string $appKey
     * @param string $appSecret
     * @param string $permissions
     * @param string $format
     * @throws RtmApiError
     */
    public function __construct($appKey, $appSecret, $permissions = 'read', $format = 'json')
    {
        if (empty($appKey) || empty($appSecret)) {
            throw new RtmApiError('Error: App Key and Secret Key must be defined.');
        }

        $this->appKey = $appKey;
        $this->appSecret = $appSecret;
        $this->permissions = $permissions;
        $this->format = $format;
    }

    /**
     * Encodes request parameters into URL format
     *
     * @param string[] $params Array of parameters to be URL encoded
     * @param bool $signed Boolean specfying whether or not the URL should be signed
     * @param bool $post Boolean specfying whether or not the URL should be get (or post which is default)
     * @return string Returns the URL encoded string of parameters
     */
    private function encodeUrlParams(array $params = [], $signed = false, $post = true)
    {
        $paramString = '';

        if (!empty($params)) {
            $count = 0;

            // Encode the parameter keys and values
            foreach ($params as $key => $value) {
                if ($count == 0) {
                    $paramString .= ($post ? '' : '?') . $key . '=' . urlencode($value);
                } else {
                    $paramString .= '&' . $key . '=' . urlencode($value);
                }
                $count++;
            }

            // Encode and append the response format paramter
            $paramString .= '&format=' . $this->format;

            // Append an auth signature if needed
            if ($signed) {
                $paramString .= $this->generateSig($params);
            }
        } else {
            throw new RtmApiError('Error: There are no parameters to encode.');
        }

        return $paramString;
    }

    /**
     * Generates a URL encoded authentication signature
     *
     * @param string[] $params The parameters used to generate the signature
     * @return string Returns the URL encoded authentication signature
     */
    private function generateSig($params = array())
    {
        $params['format'] = $this->format;

        ksort($params);
        $signature = '';
        $signatureUrl = '&api_sig=';

        foreach ($params as $key => $value) {
            $signature .= $key . $value;
        }

        $signature = $this->appSecret . $signature;
        $signatureUrl .= md5($signature);

        return $signatureUrl;
    }

    /**
     * Generates a RTM authentication URL
     *
     * @param string $frob (optional) Temporary token to generate regular token
     * @see https://www.rememberthemilk.com/services/api/authentication.rtm
     * @return string Returns the reponse from the RTM API
     */
    public function getAuthUrl($frob = '')
    {
        $params = array(
            'api_key' => $this->appKey,
            'perms' => $this->permissions
        );
        if (!empty($frob)) {
            $params['frob'] = $frob;
        }
        $url = $this->authUrl . $this->encodeUrlParams($params, true, false);
        return $url;
    }

    /**
     * Main method for making API calls
     *
     * @param string $method Specifies what API method to be used
     * @param string[] $params Array of API parameters to accompany the method parameter
     * @return mixed Returns the reponse from the RTM API via POST request however
     */
    public function get($method, $params = [])
    {
        if (empty($method)) {
            throw new RtmApiError('Error: API Method must be defined.');
        }

        // Append method to params for encoding the url params
        $params['method'] = $method;
        $params['api_key'] = $this->appKey;
        $params['v'] = '2'; // new version of API is preferred, it supports subtasks for Pro users
        //obsolete GET variant// $requestUrl = $this->baseUrl . $this->encodeUrlParams($params, true);


        $c = curl_init();
        $postFields = $this->encodeUrlParams($params, $method <> 'rtm.test.echo');
        curl_setopt($c, CURLOPT_URL, $this->baseUrl);
        curl_setopt($c, CURLOPT_POST, 1);
        curl_setopt($c, CURLOPT_POSTFIELDS, $postFields);
        curl_setopt($c, CURLOPT_RETURNTRANSFER, true); // return the payload

        //SSL
        curl_setopt($c, CURLOPT_SSL_VERIFYPEER, false);
        //@todo try without that option and if it fails, it may try with this option and inform about it
        curl_setopt($c, CURLOPT_SSL_VERIFYHOST, false); // accepts also private SSL certificates

        $response = curl_exec($c);
        if (is_bool($response)) {
            return $response;
        }
        // Decode JSON if format is json
        return ($this->format == 'json') ? json_decode($response) : $response;
    }
}
