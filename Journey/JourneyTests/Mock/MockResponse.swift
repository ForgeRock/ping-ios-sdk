// 
//  MockResponse.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

struct MockResponse {
    static let headers = ["Content-Type": "application/json"]
    
    // Return the OpenID configuration response as Data
    static var openIdConfigurationResponse: Data {
        return """
        {
            "authorization_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/authorize",
            "token_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/token",
            "userinfo_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/userinfo",
            "end_session_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/connect/endSession",
            "revocation_endpoint" : "https://openam-bafaloukas.forgeblocks.com/am/oauth2/alpha/revoke"
        }
        """.data(using: .utf8)!
    }
    /*
    // return the token response as Data
    static var tokenResponse: Data {
        return """
        {
            "access_token" : "Dummy AccessToken",
            "token_type" : "Dummy Token Type",
            "scope" : "openid email address",
            "refresh_token" : "Dummy RefreshToken",
            "expires_in" : 1,
            "id_token" : "Dummy IdToken"
        }
        """.data(using: .utf8)!
    }
    
    // return the userinfo response as Data
    static var userinfoResponse: Data {
        return """
        {
            "sub" : "test-sub",
            "name" : "test-name",
            "email" : "test-email",
            "phone_number" : "test-phone_number",
            "address" : "test-address"
        }
        """.data(using: .utf8)!
    }
    
    //  return an empty revoke response as Data
    static var revokeResponse: Data{
        return Data()
    }
    
    // Headers for the authorize response
    static let authorizeResponseHeaders: [String: String] =
    [
        "Content-Type": "application/json; charset=utf-8",
        "Set-Cookie": """
        interactionId=038e8128-272a-4a15-b97b-379aa1447149; Max-Age=3600; Path=/; Expires=Wed, 27 Mar 9999 05:06:30 GMT; HttpOnly
        """
    ]
    
    // return the authorize response as Data
    static var authorizeResponse: Data {
        return """
        {
            "_links": {
                "next": {
                    "href": "http://auth.test-one-pingone.com/customHTMLTemplate"
                }
            },
            "interactionId": "008bccea-914b-49da-b2a1-5cd3f83f4372",
            "interactionToken": "2a0d9bcdbdeb5ea14ef34d680afc45f37a56e190e306a778f01d768b271bf1e976aaf4154b633381e1299b684d3a4a66d3e1c6d419a7d20657bf4f32c741d78f67d41e08eb0e5f1070edf780809b4ccea8830866bcedb388d8f5de13e89454d353bcca86d4dcd5d7872efc929f7e5199d8d127d1b2b45499c42856ce785d8664",
            "eventName": "continue",
            "isResponseCompatibleWithMobileAndWebSdks": true,
            "id": "cq77vwelou",
            "companyId": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae",
            "flowId": "ebac77c8fbf68d3dac68c5dd804a936f",
            "connectionId": "867ed4363b2bc21c860085ad2baa817d",
            "capabilityName": "customHTMLTemplate",
            "formData": {
                "value": {
                    "username": "",
                    "password": ""
                }
            },
            "form": {
                "name": "Username/Password Form",
                "description": "Test Description",
                "category": "CUSTOM_HTML",
                "components": {
                    "fields": [
                        {
                            "type": "TEXT",
                            "key": "username",
                            "label": "Username"
                        },
                        {
                            "type": "PASSWORD",
                            "key": "password",
                            "label": "Password"
                        },
                        {
                            "type": "SUBMIT_BUTTON",
                            "key": "SIGNON",
                            "label": "Sign On"
                        },
                        {
                            "type": "FLOW_BUTTON",
                            "key": "TROUBLE",
                            "label": "Having trouble signing on?",
                            "inputType": "ACTION"
                        },
                        {
                            "type": "FLOW_BUTTON",
                            "key": "REGISTER",
                            "label": "No account? Register now!",
                            "inputType": "ACTION"
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!
    }
    
    // Headers for the custom HTML template response
    static let customHTMLTemplateHeaders: [String: String] = [
        "Content-Type": "application/json; charset=utf-8",
        "Set-Cookie": """
        ST=session_token; Max-Age=3600; Path=/; Expires=Wed, 27 Mar 9999 05:06:30 GMT; HttpOnly
        """
    ]
    
    // return the custom HTML template response as Data
    static var customHTMLTemplate: Data {
        return """
        {
            "interactionId": "033e1338-c271-4dd7-8d74-fc2eacc135d8",
            "companyId": "94e3268d-847d-47aa-a45e-1ef8dd8f4df0",
            "connectionId": "26146c8065741406afb0899484e361a7",
            "connectorId": "pingOneAuthenticationConnector",
            "id": "5dtrjnrwox",
            "capabilityName": "returnSuccessResponseRedirect",
            "environment": {
                "id": "94e3268d-847d-47aa-a45e-1ef8dd8f4df0"
            },
            "session": {
                "id": "d0598645-c2f7-4b94-adc9-401a896eaffb"
            },
            "status": "COMPLETED",
            "authorizeResponse": {
                "code": "03dbd5a2-db72-437c-8728-fc33b860083c"
            },
            "success": true,
            "interactionToken": "5ad09feac8982d668c5f07d1eaf544bdf2309247146999c0139f7ebb955c24743b97a01e3bf67360121cd85d7a9e1d966c3f4b7e27f21206a5304d305951864cc34a37900f3326f8000c7bc731af9ba78a681eb14d4bf767172e8a7149e4df3e054b4245bdea5612e9ec0c0d8cb349b55dcf10db30de075dfc79f6c765046d99"
        }
        """.data(using: .utf8)!
    }
    
    // return the custom HTML template response with invalid password as Data
    static var customHTMLTemplateWithInvalidPassword: Data {
        return """
        {
            "interactionId": "00444ecd-0901-4b57-acc3-e1245971205b",
            "companyId": "0c6851ed-0f12-4c9a-a174-9b1bf8b438ae",
            "connectionId": "94141bf2f1b9b59a5f5365ff135e02bb",
            "connectorId": "pingOneSSOConnector",
            "id": "dnu7jt3sjz",
            "capabilityName": "checkPassword",
            "errorCategory": "NotSet",
            "code": "Invalid username and/or password",
            "cause": null,
            "expected": true,
            "message": "Invalid username and/or password",
            "httpResponseCode": 400,
            "details": [
                {
                    "rawResponse": {
                        "id": "b187c1c7-e9fe-4f72-a554-1b2876babafe",
                        "code": "INVALID_DATA",
                        "message": "The request could not be completed. One or more validation errors were in the request.",
                        "details": [
                            {
                                "code": "INVALID_VALUE",
                                "target": "password",
                                "message": "The provided password did not match provisioned password",
                                "innerError": {
                                    "failuresRemaining": 4
                                }
                            }
                        ]
                    },
                    "statusCode": 400
                }
            ],
            "isResponseCompatibleWithMobileAndWebSdks": true,
            "correlationId": "b187c1c7-e9fe-4f72-a554-1b2876babafe"
        }
        """.data(using: .utf8)!
    }
    
    static var tokenErrorResponse: Data {
        return """
        {
            "error": "Invalid Grant"
        }
        """.data(using: .utf8)!
    }
    
    static var passwordValidationError: Data {
        return """
        {
          "interactionId": "18434ef7-019f-4a9e-a6d2-e3fd61ddc0c6",
          "companyId": "02fb4743-189a-4bc7-9d6c-a919edfe6447",
          "connectionId": "94141bf2f1b9b59a5f5365ff135e02bb",
          "connectorId": "pingOneSSOConnector",
          "id": "x0txd3bdfn",
          "capabilityName": "createUser",
          "errorCategory": "InvalidData",
          "code": "invalidValue",
          "cause": null,
          "expected": true,
          "message": "password: User password did not satisfy password policy requirements",
          "httpResponseCode": 400,
          "details": [
            {
              "rawResponse": {
                "id": "ffbab117-06e6-44be-a17a-ae619d3d7334",
                "code": "INVALID_DATA",
                "message": "The request could not be completed. One or more validation errors were in the request.",
                "details": [
                  {
                    "code": "INVALID_VALUE",
                    "target": "password",
                    "message": "User password did not satisfy password policy requirements",
                    "innerError": {
                      "minCharacters": "The provided password did not contain enough characters from the character set 'ZYXWVUTSRQPONMLKJIHGFEDCBA'.  The minimum number of characters from that set that must be present in user passwords is 1",
                      "unsatisfiedRequirements": [
                        "minCharacters",
                        "minCharacters",
                        "minCharacters",
                        "excludesCommonlyUsed",
                        "length",
                        "maxRepeatedCharacters",
                        "minUniqueCharacters"
                      ],
                      "minUniqueCharacters": "The provided password does not contain enough unique characters.  The minimum number of unique characters that may appear in a user password is 5",
                      "length": "The provided password is shorter than the minimum required length of 8 characters",
                      "excludesCommonlyUsed": "The provided password (or a variant of that password) was found in a list of prohibited passwords",
                      "maxRepeatedCharacters": "The provided password is not acceptable because it contains a character repeated more than 2 times in a row"
                    }
                  }
                ]
              },
              "statusCode": 400
            }
          ],
          "isResponseCompatibleWithMobileAndWebSdks": true
        }
        """.data(using: .utf8)!
        
    }
    
    static var responseWithBasicTypes: Data {
        return """
        {
          "interactionId": "18c0faef-91b9-42fa-ae39-cf6f4e0a0b33",
          "companyId": "02fb4743-189a-4bc7-9d6c-a919edfe6447",
          "connectionId": "8209285e0d2f3fc76bfd23fd10d45e6f",
          "connectorId": "pingOneFormsConnector",
          "id": "65u7m8cm28",
          "capabilityName": "customForm",
          "showContinueButton": false,
          "form": {
            "components": {
              "fields": [
                {
                  "type": "LABEL",
                  "content": "Sign On"
                },
                {
                  "type": "LABEL",
                  "content": "Welcome to Ping Identity"
                },
                {
                  "type": "ERROR_DISPLAY"
                },
                {
                  "type": "TEXT",
                  "key": "user.username",
                  "label": "Username",
                  "required": true,
                  "validation": {
                    "regex": ".",
                    "errorMessage": "Must be valid email address"
                  }
                },
                {
                  "type": "PASSWORD",
                  "key": "password",
                  "label": "Password",
                  "required": true
                },
                {
                  "type": "SUBMIT_BUTTON",
                  "label": "Sign On",
                  "key": "submit"
                },
                {
                  "type": "FLOW_LINK",
                  "key": "register",
                  "label": "No account? Register now!",
                  "inputType": "ACTION"
                },
                {
                  "type": "FLOW_LINK",
                  "key": "trouble",
                  "label": "Having trouble signing on?",
                  "inputType": "ACTION"
                },
                {
                  "type": "DROPDOWN",
                  "key": "dropdown-field",
                  "label": "Dropdown",
                  "required": true,
                  "options": [
                    {
                      "label": "dropdown1",
                      "value": "dropdown1"
                    },
                    {
                      "label": "dropdown2",
                      "value": "dropdown2"
                    },
                    {
                      "label": "dropdown3",
                      "value": "dropdown3"
                    }
                  ],
                  "inputType": "SINGLE_SELECT"
                },
                {
                  "type": "COMBOBOX",
                  "key": "combobox-field",
                  "label": "Combobox",
                  "required": true,
                  "options": [
                    {
                      "label": "combobox1",
                      "value": "combobox1"
                    },
                    {
                      "label": "combobox2",
                      "value": "combobox2"
                    }
                  ],
                  "inputType": "MULTI_SELECT"
                },
                {
                  "type": "RADIO",
                  "key": "radio-field",
                  "label": "Radio",
                  "required": true,
                  "options": [
                    {
                      "label": "radio1",
                      "value": "radio1"
                    },
                    {
                      "label": "radio2",
                      "value": "radio2"
                    }
                  ],
                  "inputType": "SINGLE_SELECT"
                },
                {
                  "type": "CHECKBOX",
                  "key": "checkbox-field",
                  "label": "Checkbox",
                  "required": true,
                  "options": [
                    {
                      "label": "checkbox1",
                      "value": "checkbox1"
                    },
                    {
                      "label": "checkbox2",
                      "value": "checkbox2"
                    }
                  ],
                  "inputType": "MULTI_SELECT"
                }
              ]
            },
            "name": "session main - signon1",
            "description": "session main flow - sign on form ",
            "category": "CUSTOM_FORM"
          },
          "theme": "activeTheme",
          "formData": {
            "value": {
              "user.username": "default-username",
              "password": "default-password",
              "dropdown-field": "default-dropdown",
              "combobox-field": ["default-combobox"],
              "radio-field": "default-radio",
              "checkbox-field": ["default-checkbox"]
            }
          },
          "returnUrl": "",
          "enableRisk": false,
          "collectBehavioralData": false,
          "universalDeviceIdentification": false,
          "pingidAgent": false,
          "linkWithP1User": true,
          "population": "usePopulationId",
          "buttonText": "Submit",
          "authenticationMethodSource": "useDefaultMfaPolicy",
          "nodeTitle": "Sign On",
          "nodeDescription": "Enter username and password",
          "backgroundColor": "#b7e9deff",
          "envId": "02fb4743-189a-4bc7-9d6c-a919edfe6447",
          "region": "CA",
          "themeId": "activeTheme",
          "formId": "f0cf83ab-f8f4-4f4a-9260-8f7d27061fa7",
          "passwordPolicy": {
            "_links": {
              "environment": {
                "href": "http://10.76.235.122:4140/directory-api/environments/02fb4743-189a-4bc7-9d6c-a919edfe6447"
              },
              "self": {
                "href": "http://10.76.235.122:4140/directory-api/environments/02fb4743-189a-4bc7-9d6c-a919edfe6447/passwordPolicies/39cad7af-3c2f-4672-9c3f-c47e5169e582"
              }
            },
            "id": "39cad7af-3c2f-4672-9c3f-c47e5169e582",
            "environment": {
              "id": "02fb4743-189a-4bc7-9d6c-a919edfe6447"
            },
            "name": "Standard",
            "description": "A standard policy that incorporates industry best practices",
            "excludesProfileData": true,
            "notSimilarToCurrent": true,
            "excludesCommonlyUsed": true,
            "maxAgeDays": 182,
            "minAgeDays": 1,
            "maxRepeatedCharacters": 2,
            "minUniqueCharacters": 5,
            "history": {
              "count": 6,
              "retentionDays": 365
            },
            "lockout": {
              "failureCount": 5,
              "durationSeconds": 900
            },
            "length": {
              "min": 8,
              "max": 255
            },
            "minCharacters": {
              "~!@#$%^&*()-_=+[]{}|;:,.<>/?": 1,
              "0123456789": 1,
              "ABCDEFGHIJKLMNOPQRSTUVWXYZ": 1,
              "abcdefghijklmnopqrstuvwxyz": 1
            },
            "populationCount": 1,
            "createdAt": "2024-01-03T19:50:39.586Z",
            "updatedAt": "2024-01-03T19:50:39.586Z",
            "default": true
          },
          "isResponseCompatibleWithMobileAndWebSdks": true,
          "fieldTypes": [
            "LABEL",
            "ERROR_DISPLAY",
            "TEXT",
            "PASSWORD",
            "RADIO",
            "CHECKBOX",
            "FLOW_LINK",
            "COMBOBOX",
            "DROPDOWN",
            "SUBMIT_BUTTON"
          ],
          "success": true,
          "interactionToken": "74fade0c6e096f45c3c884d97616a2cef16459d5a27aa6be49b6bbdf236fe7e85a57d3d4ae24ce37a27678fd3f91973559829e9010e9b1180f6844db5a9b05180cc1044b89c0edc4c0fb301a065f73d30c4a61bfbbc14c479fd34991adf819612432bd2cdce489d255c363fda8dd683121d2a432fac70a9a38b72e7f7d9b9179",
          "startUiSubFlow": true,
          "_links": {
            "next": {
              "href": "https://auth.pingone.ca/02fb4743-189a-4bc7-9d6c-a919edfe6447/davinci/connections/8209285e0d2f3fc76bfd23fd10d45e6f/capabilities/customForm"
            }
          }
        }
    """.data(using: .utf8)!
    }
    */
}
