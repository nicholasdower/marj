## 6.0.0

- Remove special handling for `id` and `queue` in `query` method.
- Fix bug where due date ordering was applied by `query` even if an ordered scope was used.
- Add support for Mission Control Jobs.
- Add `delete` method and ability to override discard behavior.

## 5.0.0

- Populate `enqueued_at` and `locale` when enqueueing.
- Add `query` and `discard` to `Marj` and `MarjAdapter`.
- Remove all existing `Marj` query methods.
- Remove `JobsInterface`.
- Remove `Marj::Relation`.

## 4.1.0

- Deserialize arguments immediately rather than lazily.

## 4.0.0

- Move `Marj::Jobs` interface into `Marj`.
- Remove `Marj::RecordInterface`. To create a custom record class, extend `Marj::Record`.

## 3.0.0

- Fixed a bug to support the case where a job is enqueued, deleted, then reenqueued via a new reference to the existing job instance.
- Removed `Marj.execute` in favor of just using `job.perform_now`.
- Introduced `Marj::Record` to replace the `ActiveRecord` functionality in `Marj`.
- Introduced `Marj::Jobs` and `Marj::Relation` to provide an interface to enqueued jobs rather than records.
- Removed `Marj.table_name`. To override the table name, set `Marj::Record.table_name` or create a custom `ActiveRecord` model class.
- Added support for using Marj to write to multiple databases.
- Added support for creating custom jobs interfaces, for instance `MyJob.next`.
- Replace `Marj::Record.ready` with `Marj::Record.ordered` and `MarjRecord.due`. Always returned jobs ordered.

## 2.1.0

- Fixed a bug to support the case where a job is enqueued, deleted, then reenqueued via a reference to the existing job instance.

## 2.0.1

- Move `app/models/marj.rb` to `lib/marj_record.rb`.

## 2.0.0

- Rename `Marj.available` to `Marj.ready`.
- Remove `Marj.work_off` in favor of documentation.
- Add `MarjConfig.table_name`.
- Add extension examples to docs.
- Improve docs.

## 1.1.0

- Use `Kernel.autoload` rather than defining a Rails engine
- Use `find_or_create_by!` rather than `find_by(...).update! || create!`
- Move public interface to the top of the `Marj` class for easier code review.
- Improve docs.

## 1.0.0

- Initial release