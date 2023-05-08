// Copyright Materialize, Inc. and contributors. All rights reserved.
//
// Use of this software is governed by the Business Source License
// included in the LICENSE file.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the Apache License, Version 2.0.

// BEGIN LINT CONFIG
// DO NOT EDIT. Automatically generated by bin/gen-lints.
// Have complaints about the noise? See the note in misc/python/materialize/cli/gen-lints.py first.
#![allow(clippy::style)]
#![allow(clippy::complexity)]
#![allow(clippy::large_enum_variant)]
#![allow(clippy::mutable_key_type)]
#![allow(clippy::stable_sort_primitive)]
#![allow(clippy::map_entry)]
#![allow(clippy::box_default)]
#![warn(clippy::bool_comparison)]
#![warn(clippy::clone_on_ref_ptr)]
#![warn(clippy::no_effect)]
#![warn(clippy::unnecessary_unwrap)]
#![warn(clippy::dbg_macro)]
#![warn(clippy::todo)]
#![warn(clippy::wildcard_dependencies)]
#![warn(clippy::zero_prefixed_literal)]
#![warn(clippy::borrowed_box)]
#![warn(clippy::deref_addrof)]
#![warn(clippy::double_must_use)]
#![warn(clippy::double_parens)]
#![warn(clippy::extra_unused_lifetimes)]
#![warn(clippy::needless_borrow)]
#![warn(clippy::needless_question_mark)]
#![warn(clippy::needless_return)]
#![warn(clippy::redundant_pattern)]
#![warn(clippy::redundant_slicing)]
#![warn(clippy::redundant_static_lifetimes)]
#![warn(clippy::single_component_path_imports)]
#![warn(clippy::unnecessary_cast)]
#![warn(clippy::useless_asref)]
#![warn(clippy::useless_conversion)]
#![warn(clippy::builtin_type_shadow)]
#![warn(clippy::duplicate_underscore_argument)]
#![warn(clippy::double_neg)]
#![warn(clippy::unnecessary_mut_passed)]
#![warn(clippy::wildcard_in_or_patterns)]
#![warn(clippy::crosspointer_transmute)]
#![warn(clippy::excessive_precision)]
#![warn(clippy::overflow_check_conditional)]
#![warn(clippy::as_conversions)]
#![warn(clippy::match_overlapping_arm)]
#![warn(clippy::zero_divided_by_zero)]
#![warn(clippy::must_use_unit)]
#![warn(clippy::suspicious_assignment_formatting)]
#![warn(clippy::suspicious_else_formatting)]
#![warn(clippy::suspicious_unary_op_formatting)]
#![warn(clippy::mut_mutex_lock)]
#![warn(clippy::print_literal)]
#![warn(clippy::same_item_push)]
#![warn(clippy::useless_format)]
#![warn(clippy::write_literal)]
#![warn(clippy::redundant_closure)]
#![warn(clippy::redundant_closure_call)]
#![warn(clippy::unnecessary_lazy_evaluations)]
#![warn(clippy::partialeq_ne_impl)]
#![warn(clippy::redundant_field_names)]
#![warn(clippy::transmutes_expressible_as_ptr_casts)]
#![warn(clippy::unused_async)]
#![warn(clippy::disallowed_methods)]
#![warn(clippy::disallowed_macros)]
#![warn(clippy::disallowed_types)]
#![warn(clippy::from_over_into)]
// END LINT CONFIG

use mz_ore::metrics::HistogramVecExt;
use mz_rocksdb::{Options, RocksDBInstance, RocksDBMetrics};
use prometheus::{HistogramOpts, HistogramVec};

fn metrics_for_tests() -> Result<Box<RocksDBMetrics>, anyhow::Error> {
    let fake_hist_vec =
        HistogramVec::new(HistogramOpts::new("fake", "fake_help"), &["fake_label"])?;

    Ok(Box::new(RocksDBMetrics {
        multi_get_latency: fake_hist_vec.get_delete_on_drop_histogram(vec!["one".to_string()]),
        multi_get_size: fake_hist_vec.get_delete_on_drop_histogram(vec!["two".to_string()]),
        multi_put_latency: fake_hist_vec.get_delete_on_drop_histogram(vec!["three".to_string()]),
        multi_put_size: fake_hist_vec.get_delete_on_drop_histogram(vec!["four".to_string()]),
    }))
}

#[tokio::test]
async fn basic() -> Result<(), anyhow::Error> {
    // If the test aborts, this may not be cleaned up.
    let t = tempfile::tempdir()?;

    let mut instance = RocksDBInstance::<String, String>::new(
        t.path(),
        Options::new_with_defaults()?,
        metrics_for_tests()?,
    )
    .await?;

    let mut ret = vec![None; 1];
    instance
        .multi_get(vec!["one".to_string()], ret.iter_mut())
        .await?;

    assert_eq!(ret.split_off(0), vec![None]);

    instance
        .multi_put(vec![
            ("one".to_string(), Some("onev".to_string())),
            // Deleting a non-existent key shouldn't do anything
            ("two".to_string(), None),
        ])
        .await?;

    let mut ret = vec![None; 2];
    instance
        .multi_get(vec!["one".to_string(), "two".to_string()], ret.iter_mut())
        .await?;

    assert_eq!(ret.split_off(0), vec![Some("onev".to_string()), None]);

    instance
        .multi_put(vec![
            // Double-writing a key should keep the last one.
            ("two".to_string(), Some("twov1".to_string())),
            ("two".to_string(), Some("twov2".to_string())),
        ])
        .await?;

    let mut ret = vec![None; 2];
    instance
        .multi_get(vec!["one".to_string(), "two".to_string()], ret.iter_mut())
        .await?;

    assert_eq!(
        ret.split_off(0),
        vec![Some("onev".to_string()), Some("twov2".to_string())]
    );

    instance.close().await?;

    Ok(())
}
