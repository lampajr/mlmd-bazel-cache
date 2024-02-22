# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# TODO(b/195701120) Introduces l.gcr.io/google/bazel:5.3.0 when it is available
# and makes sure that it uses ubuntu 20.04 as base image. Currently the lastest
# version only supports bazel 3.5.0.

ARG SOURCE_CODE=.

#FROM registry.access.redhat.com/ubi8/ubi:8.9 as fetcher
FROM registry.redhat.io/ubi8/ubi:8.9

RUN dnf update -y -q && \
  dnf install -y -q \
  which \
  patch \
  gcc \
  clang \
  cmake \
  make \
  openssl \
  ca-certificates \
  unzip \
  git \
  python3 \
  python3-devel

#RUN git clone https://github.com/opendatahub-io/ml-metadata.git /mlmd-src
WORKDIR /mlmd-src
COPY ${SOURCE_CODE} .

ENV BAZEL_VERSION 5.3.0
# I'd suggest to use exactly the same RPM you are using for your disconnected/offline build
ENV BAZEL_LOCAL_RPM bazel-5.3.0-1.el8.x86_64.rpm
RUN if [ -f ${BAZEL_LOCAL_RPM} ]; then \
       echo "Installing local bazel RPM.." && \
       dnf install -y -q bazel-5.3.0-1.el8.x86_64.rpm; \
    else \
       echo "Downloading bazel.." && \
       mkdir /bazel && \
       cd /bazel && \
       curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
       curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE && \
       chmod +x bazel-*.sh && \
       ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
       cd / && \
       rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh; \
    fi

WORKDIR /mlmd-src

RUN bazel sync; exit 0

ENTRYPOINT "/bin/sh"
