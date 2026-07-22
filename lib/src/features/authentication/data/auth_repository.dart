// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:graphql/client.dart';

import '../../../graphql/__generated__/schema.graphql.dart';
import '../../../utils/extensions/custom_extensions.dart';
import '../domain/auth_tokens.dart';
import 'graphql/__generated__/query.graphql.dart';

class AuthRepository {
  const AuthRepository(this.client);

  final GraphQLClient client;

  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    final payload = await client
        .mutate$Login(
          Options$Mutation$Login(
            variables: Variables$Mutation$Login(
              input: Input$LoginInput(
                username: username,
                password: password,
              ),
            ),
          ),
        )
        .getData((data) => data.login);

    if (payload == null ||
        payload.accessToken.isEmpty ||
        payload.refreshToken.isEmpty) {
      throw const FormatException('The server returned invalid login tokens');
    }

    return AuthTokens(
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
    );
  }

  Future<String> refreshAccessToken(String refreshToken) async {
    final payload = await client
        .mutate$RefreshAccessToken(
          Options$Mutation$RefreshAccessToken(
            variables: Variables$Mutation$RefreshAccessToken(
              input: Input$RefreshTokenInput(refreshToken: refreshToken),
            ),
          ),
        )
        .getData((data) => data.refreshToken);

    if (payload == null || payload.accessToken.isEmpty) {
      throw const FormatException('The server returned an invalid access token');
    }
    return payload.accessToken;
  }
}
