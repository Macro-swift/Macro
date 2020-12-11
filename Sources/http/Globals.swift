//
//  Globals.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import NIOHTTP1

public extension HTTPModule {
  
  /**
   * The available methods in `NIOHTTP1.HTTPMethod`. Note that
   * `HTTPMethod` also supports a custom case.
   */
  static var METHODS : [ String ] = [
    "GET",
    "PUT",
    "ACL",
    "HEAD",
    "POST",
    "COPY",
    "LOCK",
    "MOVE",
    "BIND",
    "LINK",
    "PATCH",
    "TRACE",
    "MKCOL",
    "MERGE",
    "PURGE",
    "NOTIFY",
    "SEARCH",
    "UNLOCK",
    "REBIND",
    "UNBIND",
    "REPORT",
    "DELETE",
    "UNLINK",
    "CONNECT",
    "MSEARCH",
    "OPTIONS",
    "PROPFIND",
    "CHECKOUT",
    "PROPPATCH",
    "SUBSCRIBE",
    "MKCALENDAR",
    "MKACTIVITY",
    "UNSUBSCRIBE",
    "SOURCE"
  ]
  
  /**
   * The available cases in `NIOHTTP1.HTTPResponseStatus`. Note that
   * `HTTPResponseStatus` also supports a custom case.
   */
  static var STATUS_CASES : [ HTTPResponseStatus ] = [
    .`continue`,
    .switchingProtocols,
    .processing,
    .ok,
    .created,
    .accepted,
    .nonAuthoritativeInformation,
    .noContent,
    .resetContent,
    .partialContent,
    .multiStatus,
    .alreadyReported,
    .imUsed,
    .multipleChoices,
    .movedPermanently,
    .found,
    .seeOther,
    .notModified,
    .useProxy,
    .temporaryRedirect,
    .permanentRedirect,
    .badRequest,
    .unauthorized,
    .paymentRequired,
    .forbidden,
    .notFound,
    .methodNotAllowed,
    .notAcceptable,
    .proxyAuthenticationRequired,
    .requestTimeout,
    .conflict,
    .gone,
    .lengthRequired,
    .preconditionFailed,
    .payloadTooLarge,
    .uriTooLong,
    .unsupportedMediaType,
    .rangeNotSatisfiable,
    .expectationFailed,
    .imATeapot,
    .misdirectedRequest,
    .unprocessableEntity,
    .locked,
    .failedDependency,
    .upgradeRequired,
    .preconditionRequired,
    .tooManyRequests,
    .requestHeaderFieldsTooLarge,
    .unavailableForLegalReasons,
    .internalServerError,
    .notImplemented,
    .badGateway,
    .serviceUnavailable,
    .gatewayTimeout,
    .httpVersionNotSupported,
    .variantAlsoNegotiates,
    .insufficientStorage,
    .loopDetected,
    .notExtended,
    .networkAuthenticationRequired
  ]
  
  /**
   * A non-exhaustive collection of known HTTP response status codes.
   */
  static var STATUS_CODES = [ Int : String ](
    uniqueKeysWithValues: STATUS_CASES.map { status in
      ( Int(status.code), status.reasonPhrase )
    }
  )
}
