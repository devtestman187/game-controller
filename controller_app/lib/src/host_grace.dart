/// How long the app may stay hidden before the round is abandoned (m12 §2.10).
///
/// A phone that shows a host's game counts the same number down from the
/// moment its link to the host drops (m12-joined-view §0.3): a suspended host
/// says nothing, so the phone measures the grace itself.
const int hostGraceS = 30;
