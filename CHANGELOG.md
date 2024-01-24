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