# Copyright Materialize, Inc. and contributors. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

import requests

from materialize.mzcompose import Composition
from materialize.mzcompose.services import Materialized, Testdrive

SERVICES = [
    Materialized(environment_extra=[
            "MZ_DEPLOY_GENERATION=2",
        ]),
    Testdrive(),
]

def workflow_default(c: Composition) -> None:
    """
    c.up("materialized")
    print("started materialize")

    with c.override(Materialized(environment_extra=[
            "MZ_DEPLOY_GENERATION=3",
        ])):
        c.up("materialized")
        print("started materialize with deploy_generation=3")
        internal_port = c.port("materialized", 6878)

        while True:
            info = requests.get(f"http://localhost:{internal_port}/api/leader/status").json()
            print("Got leader status:", info)
            if info.status == "ReadyToPromote":
                break

        result = requests.post(f"http://localhost:{internal_port}/api/leader/promote").json()
        print("After promotion received {result}")

        assert c.sql_query("SELECT 1") == [[1]]
    """
    print("hello world")
    assert False