import ceb::router;
import std::io;

fn void test_dynamic_paths() @test {
  if (catch err = router::is_dynamic_path("/test")) {
    assert(false, "err");
  }
}