import 'package:flutter_test/flutter_test.dart';
import 'package:vidalis_mobile/core/models/upload_job.dart';
import 'package:vidalis_mobile/core/services/upload_queue.dart';

void main() {
  group('UploadQueue', () {
    late UploadQueue queue;

    setUp(() {
      queue = UploadQueue();
    });

    test('starts empty', () {
      expect(queue.activeJob, isNull);
      expect(queue.hasActiveJob, isFalse);
    });

    test('enqueue sets activeJob', () {
      final job = UploadJob(id: 'job1', artistId: 'a1', title: 'Test');
      queue.enqueue(job);
      expect(queue.activeJob?.id, 'job1');
      expect(queue.hasActiveJob, isTrue);
    });

    test('enqueue ignores second job when one is active', () {
      final job1 = UploadJob(id: 'job1', artistId: 'a1');
      final job2 = UploadJob(id: 'job2', artistId: 'a2');
      queue.enqueue(job1);
      queue.enqueue(job2);
      expect(queue.activeJob?.id, 'job1');
    });

    test('update replaces activeJob', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      final updated = job.copyWith(status: UploadStatus.uploading, progress: 0.5);
      queue.update(updated);
      expect(queue.activeJob?.status, UploadStatus.uploading);
      expect(queue.activeJob?.progress, 0.5);
    });

    test('complete marks job as done', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      queue.complete();
      expect(queue.activeJob?.status, UploadStatus.done);
    });

    test('fail marks job as failed with message', () {
      final job = UploadJob(id: 'job1', artistId: 'a1');
      queue.enqueue(job);
      queue.fail('Red caída');
      expect(queue.activeJob?.status, UploadStatus.failed);
      expect(queue.activeJob?.errorMessage, 'Red caída');
    });

    test('notifies listeners on enqueue', () {
      var notified = false;
      queue.addListener(() => notified = true);
      queue.enqueue(UploadJob(id: 'j', artistId: 'a'));
      expect(notified, isTrue);
    });
  });
}
