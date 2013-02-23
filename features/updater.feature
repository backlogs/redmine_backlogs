Feature: Team Member
  As a team member
  I want to manage update stories and tasks
  So that I can update everyone on the status of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And sharing is enabled
      And I have defined the following projects:
        | name   |
        | p1     |
        | p1s1   |
        | p1s2   |

      And the p1 project has the backlogs plugin enabled
      And the p1s1 project has the backlogs plugin enabled
      And the p1s1 project is subproject of the p1 project
      And the p1s2 project has the backlogs plugin enabled
      And the p1s2 project is subproject of the p1 project
      And no versions or issues exist
      And I am a team member of the project

      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date | sharing     | project_id    |
        | Sp000      | 2010-01-01        | 2010-01-31     | hierarchy   | p1            |
        | Sp001      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s1          |
        | Sp002      | 2010-01-01        | 2010-01-31     | hierarchy   | p1s2          |

      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date  | project_id  |
        | Sp003      | 2012-11-01        | 2012-11-30      | p1          |
        | Sp004      | 2012-12-01        | 2012-12-31      | p1          |
        | Sp005      | 2012-12-01        | 2012-12-31      | p1s1        |
        | Sp006      | 2012-12-01        | 2012-12-31      | p1s2        |
      And the current time is 2012-11-20 08:00:00
      And I have defined the following stories in the following sprints:
        | subject | sprint     | project_id |
        | Story 1 | Sp000      | p1  |
        | Story 2 | Sp000      | p1  |
        | Story 3 | Sp000      | p1  |
        | Story 4 | Sp001      | p1  |

  Scenario: Fetch the updated stories
    Given I have selected the p1 project
    Given I am viewing the master backlog
     When the browser fetches stories updated since 1 week ago
     Then the server should return 4 updated stories

  Scenario: Fetch stories from one project
    Given the current time is 2012-11-21 08:00:00
    Given I have selected the p1 project
    Given I have defined the following stories in the product backlog:
        | subject | project_id  |
        | Story u1 | p1   |
        | Story u2 | p1   |
        | Story u6 | p1s1 |
        | Story u7 | p1s1 |
        | Story u3 | p1   |
        | Story u4 | p1   |
        | Story u8 | p1s1 |
        | Story u9 | p1s1 |
    Given I have selected the p1s1 project
      And sharing is not enabled
     When the browser fetches stories updated since 1 week ago
     Then the server should return 4 updated stories
    Given I have selected the p1 project
     When the browser fetches stories updated since 1 week ago
     Then the server should return 8 updated stories

    Given I have selected the p1s1 project
      And sharing is enabled
     When the browser fetches stories updated since 1 week ago
     Then the server should return 4 updated stories
    Given I have selected the p1 project
     When the browser fetches stories updated since 1 week ago
     Then the server should return 12 updated stories
