require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end
    
    describe 'when joining aggregated relations' do
      before do
        @aggregation = @relation2                                           \
          .group(@relation2[:user_id])                                      \
          .project(@relation2[:user_id], @relation2[:id].count.as(:cnt))    \
      end
      
      describe '#to_sql' do
        describe 'with the aggregation on the right' do
          it 'manufactures sql joining the left table to a derived table' do
            @relation1.join(@aggregation).on(@predicate).to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`
              FROM `users`
                INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                  ON `users`.`id` = `photos_aggregation`.`user_id`
            ")
          end
        end

        describe 'with the aggregation on the left' do
          it 'manufactures sql joining the right table to a derived table' do
            @aggregation.join(@relation1).on(@predicate).to_sql.should be_like("
              SELECT `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`, `users`.`id`, `users`.`name`
              FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                INNER JOIN `users`
                  ON `users`.`id` = `photos_aggregation`.`user_id`
            ")
          end
        end
        
        describe 'with the aggregation on both sides' do
          it 'it properly aliases the aggregations' do
            aggregation2 = @aggregation.alias
            @aggregation.join(aggregation2).on(aggregation2[:user_id].eq(@aggregation[:user_id])).to_sql.should be_like("
              SELECT `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`, `photos_aggregation_2`.`user_id`, `photos_aggregation_2`.`cnt`
              FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY  `photos`.`user_id`) AS `photos_aggregation`
                INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photos_aggregation_2`
                  ON `photos_aggregation_2`.`user_id` = `photos_aggregation`.`user_id`
            ")
          end
        end

        describe 'when the aggration has a where' do
          describe 'with the aggregation on the left' do
            it "manufactures sql keeping wheres on the aggregation within the derived table" do
              @relation1.join(@aggregation.where(@aggregation[:user_id].eq(1))).on(@predicate).to_sql.should be_like("
                SELECT `users`.`id`, `users`.`name`, `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`
                FROM `users`
                  INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                    ON `users`.`id` = `photos_aggregation`.`user_id`
              ")
            end
          end
          
          describe 'with the aggregation on the right' do
            it "manufactures sql keeping wheres on the aggregation within the derived table" do
              @aggregation.where(@aggregation[:user_id].eq(1)).join(@relation1).on(@predicate).to_sql.should be_like("
                SELECT `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`, `users`.`id`, `users`.`name`
                FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                  INNER JOIN `users`
                    ON `users`.`id` = `photos_aggregation`.`user_id`
              ")
            end
          end
        end
      end
    end
  end
end