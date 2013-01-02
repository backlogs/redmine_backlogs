Feature: Release burndown
  As a product owner
  I want to analyze the progress of my releases
  So that i can get a feeling for the projects progress

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | In Progress |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |
      And the current time is 2011-01-01 08:00:00
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2011-01-02        | 2011-01-31     |
        | Sprint 002 | 2011-02-01        | 2011-02-28     |
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date | initial_story_points |
        | Rel 1   | ecookbook  | 2011-01-02         | 2011-02-28       | 0 |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story 1 | Rel 1   | 2 |
        | Story 2 | Rel 1   | 7 |
        | Story 5 |         | 40 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story A | Sprint 001 | Rel 1   | 2 |
        | Story B | Sprint 002 | Rel 1   | 3 |

   Scenario: Simple release burndown
    Given I view the release page
     Then release "Rel 1" should have 14 initial story points
    Given I have made the following story mutations:
        | day | story | status      |
        | 1   | A     | In Progress |
        | 2   | A     | Accepted    |
        | 3   | B     | Feedback    |
        | 4   | B     | Rejected    |
     Then the release burndown should be:
        | day   | remaining | completed | added | predicted end date
        | start | 14        | 0         | 0     | NaN
        | 1     | 14        | 0         | 0     | NaN
        | 2     | 12        | 2         | 0     | 2011-03-01
        | 3     | 12        | 2         | 0     | 2011-03-01
        | 4     | 9         | 5         | 0     | 2011-03-01
        | 5     | 9         | 5         | 0     | 2011-03-01

#   Scenario: Add complexity by re-estimating a story
#    Given the current time is 2011-01-15 08:00:00
#     When I update story "Story 3" to 13 story points
#
#   Scenario: Add a story to running release
#    Given the current time is 2011-01-15 08:00:00
#     When I add a story to release "Rel 1"
#
#   Scenario: Copy a story
#    Given the current time is 2011-01-31 08:00:00
#     When I copy story "Story A" into "Story A.cont"
#     When I reject story "Story A"
#     When update story "Story A.cont" to 5 story points
#
